// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsCustomization
import Combine
import Foundation
import Observation
import YouTubePlayerKit

/// Owns the hidden YouTube player and coordinates launcher, game, and user playback actions.
@MainActor
@Observable
package final class BackgroundMusicController {
	var player: YouTubePlayer?
	var playbackState: YouTubePlayer.PlaybackState?
	package var operation: BackgroundMusicOperation = .idle
	var playbackExpectation: BackgroundMusicPlaybackExpectation?

	let lifecycle: LauncherLifecycleStore
	let settings: LauncherPreferencesController
	let nowPlaying: NowPlayingCoordinator
	let playerCommands: BackgroundMusicPlayerCommands
	let clock: any Clock<Duration>
	let openURL: (URL) -> Void
	package var currentMusicTitle: String?
	var currentMusicVideoID: String?
	var currentSource: YouTubePlayer.Source?
	/// Changes only through `transition(_:)`, apart from tests that stage a phase.
	var phase: MusicPhase = .off
	/// Picks the first playlist track; the argument is the playlist length.
	let randomIndex: (Int) -> Int
	@ObservationIgnored var didStartCurrentPlaylist = false
	@ObservationIgnored var consecutiveFailures = 0
	@ObservationIgnored let eventSlot = TaskSlot()
	@ObservationIgnored let sourceChangeSlot = TaskSlot()
	@ObservationIgnored let playerSlot = TaskSlot()
	@ObservationIgnored let loadingSlot = TaskSlot()
	@ObservationIgnored let operationSlot = TaskSlot()
	@ObservationIgnored let expectationSlot = TaskSlot()
	@ObservationIgnored let fadeSlot = TaskSlot()
	@ObservationIgnored let volumeSlot = TaskSlot()
	@ObservationIgnored let titleSlot = TaskSlot()
	/// The running fade; `fadeSlot` owns it. Non-nil only while a fade runs.
	@ObservationIgnored var fadeTask: Task<Void, Never>?
	/// The running track or playback change; `operationSlot` decides whether its result is current.
	@ObservationIgnored var operationTask: Task<Void, Never>?
	@ObservationIgnored var playerGeneration: TaskSlot.Token
	@ObservationIgnored var lastObservedTitle: String?
	@ObservationIgnored var lastObservedVideoID: String?

	package convenience init(
		lifecycle: LauncherLifecycleStore,
		settings: LauncherPreferencesController,
		launcherIconManager: LauncherIconManager,
		initialMusicTitle: String? = nil,
		openURL: @escaping (URL) -> Void
	) {
		self.init(
			lifecycle: lifecycle,
			settings: settings,
			launcherIconManager: launcherIconManager,
			initialMusicTitle: initialMusicTitle,
			playerCommands: .live,
			openURL: openURL
		)
	}

	init(
		lifecycle: LauncherLifecycleStore,
		settings: LauncherPreferencesController,
		launcherIconManager: LauncherIconManager,
		initialMusicTitle: String? = nil,
		playerCommands: BackgroundMusicPlayerCommands = .live,
		clock: any Clock<Duration> = ContinuousClock(),
		randomIndex: @escaping (Int) -> Int = { Int.random(in: 0..<$0) },
		openURL: @escaping (URL) -> Void
	) {
		self.randomIndex = randomIndex
		self.lifecycle = lifecycle
		self.settings = settings
		self.playerCommands = playerCommands
		self.clock = clock
		self.openURL = openURL
		playerGeneration = playerSlot.begin()
		currentMusicTitle = initialMusicTitle
		nowPlaying = NowPlayingCoordinator(icon: launcherIconManager.currentIcon)
		launcherIconManager.iconDidChange = { [weak self] icon in
			self?.nowPlaying.updateArtwork(icon)
		}
	}

	/// Sleeps on the injected clock with 10% leeway.
	func sleep(for duration: Duration) async throws {
		try await clock.sleep(for: duration, tolerance: duration / 10)
	}

	var isPlaying: Bool {
		if let playbackIntent { return playbackIntent == .playing }
		return playbackState == .playing || playbackState == .buffering
	}

	/// True from the single game fade-out until the game process ends.
	var isSilencedForGame: Bool { phase.isSilencedForGame }

	var isUnavailable: Bool { phase.isUnavailable }

	func transition(_ event: MusicPhaseEvent) {
		phase = phase.applying(event)
	}

	var isChangingTrack: Bool { operation.isChangingTrack }

	var isChangingPlayback: Bool { operation.isChangingPlayback }

	var playbackIntent: PlaybackIntent? {
		guard let playbackExpectation, isCurrent(playbackExpectation) else { return nil }
		return playbackExpectation.intent
	}

	var canNavigatePlaylist: Bool {
		guard case .playlist = currentSource else { return false }
		return true
	}

	var controlsAreUnavailable: Bool {
		phase == .off || lifecycle.activity.hasGameProcess
	}

	var isMuted: Bool { settings.launcherMusicMuted }

	var effectiveVolume: Double {
		isMuted ? 0 : settings.launcherMusicVolume
	}

	func startIfNeeded() {
		guard !lifecycle.state.refresh.isChecking,
			settings.playsLauncherMusic,
			!lifecycle.activity.hasGameProcess
		else { return }
		setupPlayer()
	}

	func refreshDidChange(isChecking: Bool) {
		guard !isChecking, player == nil else { return }
		startIfNeeded()
	}

	func sourceDidChange() {
		guard settings.playsLauncherMusic, !lifecycle.activity.hasGameProcess else { return }
		sourceChangeSlot.replace { [weak self, clock] token in
			do {
				let debounce = AppConstants.Music.sourceChangeDebounce
				try await clock.sleep(for: debounce, tolerance: debounce / 10)
			} catch {
				return
			}
			guard let self, sourceChangeSlot.owns(token) else { return }
			sourceChangeSlot.invalidate()
			guard settings.playsLauncherMusic, !lifecycle.activity.hasGameProcess else {
				return
			}
			if let source = parsedYouTubeSource, player != nil, currentSource == source { return }
			setupPlayer()
		}
	}

	func enabledDidChange(to isEnabled: Bool) {
		if isEnabled {
			// During a game the normal path starts playback after the game ends.
			if !lifecycle.activity.hasGameProcess { setupPlayer() }
		} else {
			stopAndClearPlayer()
		}
	}

	func volumeDidChange(to volume: Double) {
		guard fadeTask == nil else { return }
		scheduleVolumeUpdate(to: isMuted ? 0 : volume)
	}

	func toggleMute() {
		settings.launcherMusicMuted.toggle()
		// A running fade reads the volume at every step; it must still finish and pause.
		guard fadeTask == nil else { return }
		scheduleVolumeUpdate(to: effectiveVolume)
	}

	/// The launcher music keeps playing while the game loads and fades out once, when its window appears.
	func gameActivityDidChange(to activity: LauncherActivity) {
		if case .runningGame = activity {
			guard !isSilencedForGame else { return }
			transition(.gameWindowAppeared)
			if isSilencedForGame { performFadeOut() }
		} else if !activity.hasGameProcess {
			// A launch that stops before the window appears never silenced the music.
			let wasSilenced = isSilencedForGame
			transition(.gameProcessEnded)
			guard settings.playsLauncherMusic, !phase.isUserPaused else { return }
			if phase == .off {
				startIfNeeded()
			} else if wasSilenced {
				performFadeIn()
			}
		}
	}

	func togglePlayback() {
		guard !controlsAreUnavailable, !isChangingTrack, !isChangingPlayback else { return }
		if isPlaying {
			pauseFromUserAction()
		} else {
			transition(.userResumed)
			guard let player else { return }
			let operation = beginOperation(.playbackChange(.playing))
			performFadeIn(on: player, userPlaybackOperation: operation)
		}
	}

	func playNextTrack() {
		changeTrack(direction: .next)
	}

	func playPreviousTrack() {
		changeTrack(direction: .previous)
	}

	func stop() {
		stopAndClearPlayer()
	}

	private func setupPlayer() {
		guard let source = parsedYouTubeSource else {
			stopAndClearPlayer()
			lifecycle.log.error("Background music failed: invalid YouTube URL")
			return
		}
		let sourceType = sourceTypeName(source)

		invalidatePlayerTasks()
		didStartCurrentPlaylist = false
		consecutiveFailures = 0
		currentSource = source
		transition(.sourceLoaded)

		if let player {
			observeEvents(of: player)
			loadingSlot.replace { [weak self] token in
				guard let self else { return }
				do {
					let isNewSource = player.source == nil || player.source != source
					if isNewSource {
						try await playerCommands.load(player, source)
					}
					guard loadingSlot.owns(token) else { return }
					lifecycle.log.info("Background music loaded source type: \(sourceType)")
					// A freshly cued playlist starts from its `.cued` event, once YouTube knows its tracks.
					if !(isNewSource && source.isPlaylist) { performFadeIn(on: player) }
				} catch {
					guard loadingSlot.owns(token) else { return }
					lifecycle.log.error(
						"Background music failed to load source: \(error.localizedDescription)"
					)
				}
				guard loadingSlot.owns(token) else { return }
				loadingSlot.invalidate()
			}
			return
		}

		let newPlayer = YouTubePlayer(
			source: source,
			parameters: .init(
				// A playlist starts on a random track, so it must not play track 0 first.
				autoPlay: !source.isPlaylist,
				showControls: false,
				restrictRelatedVideosToSameChannel: false
			)
		)
		lifecycle.log.info("Background music initializing player with source type: \(sourceType)")
		player = newPlayer
		observeEvents(of: newPlayer)
	}

	var parsedYouTubeSource: YouTubePlayer.Source? {
		let trimmedURL = settings.launcherMusicURL.trimmingCharacters(in: .whitespacesAndNewlines)
		guard
			let url = URL(string: trimmedURL),
			let host = url.host?.lowercased()
		else { return nil }

		if host.contains("youtube.com") || host.contains("youtu.be") {
			if let listID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
				.queryItems?.first(where: { $0.name == "list" })?.value
			{
				return .playlist(id: listID)
			}
			if host.contains("youtu.be") {
				return .video(id: url.lastPathComponent)
			}
			if let videoID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
				.queryItems?.first(where: { $0.name == "v" })?.value
			{
				return .video(id: videoID)
			}
		}
		return .init(url: url)
	}

	private func sourceTypeName(_ source: YouTubePlayer.Source) -> String {
		if case .playlist = source { return "playlist" }
		if case .video = source { return "video" }
		return "custom URL"
	}

	package func openCurrentMusicURL() {
		if let currentMusicVideoID,
			let url = URL(string: "https://www.youtube.com/watch?v=\(currentMusicVideoID)")
		{
			openURL(url)
			return
		}
		let trimmed = settings.launcherMusicURL.trimmingCharacters(in: .whitespacesAndNewlines)
		if let url = URL(string: trimmed) { openURL(url) }
	}

}
