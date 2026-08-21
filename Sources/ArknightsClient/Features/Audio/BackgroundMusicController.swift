// SPDX-License-Identifier: MPL-2.0

import Combine
import Foundation
import Observation
import YouTubePlayerKit

/// Owns the hidden YouTube player and coordinates launcher, game, and user playback actions.
@MainActor
@Observable
final class BackgroundMusicController {
	var player: YouTubePlayer?
	var playbackState: YouTubePlayer.PlaybackState?
	var isChangingTrack = false
	var isChangingPlayback = false
	var isMuted = false

	let model: LauncherViewModel
	let nowPlaying: NowPlayingCoordinator
	var currentSource: YouTubePlayer.Source?
	var isManuallyPaused = false
	var playbackIntent: PlaybackIntent?
	@ObservationIgnored var cancellables: Set<AnyCancellable> = []
	@ObservationIgnored var didShuffleCurrentPlaylist = false
	@ObservationIgnored var fadeTask: Task<Void, Never>?
	@ObservationIgnored var loadingTask: Task<Void, Never>?
	@ObservationIgnored var controlTask: Task<Void, Never>?
	@ObservationIgnored var shuffleTask: Task<Void, Never>?
	@ObservationIgnored var volumeTask: Task<Void, Never>?
	@ObservationIgnored var activeControlID: UUID?
	@ObservationIgnored var activeFadeID: UUID?
	@ObservationIgnored var lastObservedTitle: String?
	@ObservationIgnored var lastObservedVideoID: String?

	init(model: LauncherViewModel) {
		self.model = model
		nowPlaying = NowPlayingCoordinator(icon: model.launcherIconManager.currentIcon)
		model.launcherIconManager.iconDidChange = { [weak self] icon in
			self?.nowPlaying.updateArtwork(icon)
		}
		#if DEBUG
			if model.developerScenario == .musicPlayer {
				let previewSource = YouTubePlayer.Source.playlist(id: "developer-preview")
				currentSource = previewSource
				playbackState = .playing
			}
		#endif
	}

	var isPlaying: Bool {
		if let playbackIntent { return playbackIntent == .playing }
		return playbackState == .playing || playbackState == .buffering
	}

	var canNavigatePlaylist: Bool {
		guard case .playlist = currentSource else { return false }
		return true
	}

	var controlsAreDisabled: Bool {
		#if DEBUG
			if model.developerScenario == .musicPlayer { return false }
		#endif
		return player == nil || model.isGameProcessRunning || isChangingTrack || isChangingPlayback
	}

	var effectiveVolume: Double {
		isMuted ? 0 : model.launcherMusicVolume
	}

	func startIfNeeded() {
		#if DEBUG
			if model.developerScenario == .musicPlayer { return }
		#endif
		guard model.phase != .checking,
			model.playsLauncherMusic,
			!model.isGameProcessRunning
		else { return }
		setupPlayer()
	}

	func phaseDidChange(from oldPhase: LauncherPhase, to newPhase: LauncherPhase) {
		guard oldPhase == .checking, newPhase != .checking, player == nil else { return }
		startIfNeeded()
	}

	func sourceDidChange() {
		guard model.playsLauncherMusic, !model.isGameProcessRunning else { return }
		setupPlayer()
	}

	func enabledDidChange(to isEnabled: Bool) {
		if isEnabled {
			isManuallyPaused = false
			setupPlayer()
		} else {
			stopAndClearPlayer()
		}
	}

	func volumeDidChange(to volume: Double) {
		guard fadeTask == nil else { return }
		volumeTask?.cancel()
		volumeTask = Task { [weak self] in
			guard let self else { return }
			await applyVolume(isMuted ? 0 : volume)
			guard !Task.isCancelled else { return }
			volumeTask = nil
		}
	}

	func toggleMute() {
		isMuted.toggle()
		fadeTask?.cancel()
		fadeTask = nil
		activeFadeID = nil
		volumeTask?.cancel()
		volumeTask = Task { [weak self] in
			guard let self else { return }
			await applyVolume(effectiveVolume)
			guard !Task.isCancelled else { return }
			volumeTask = nil
		}
	}

	func gameRunningDidChange(to isRunning: Bool) {
		if isRunning {
			performFadeOut()
		} else if model.playsLauncherMusic, !isManuallyPaused {
			if player == nil {
				setupPlayer()
			} else {
				performFadeIn()
			}
		}
	}

	func togglePlayback() {
		guard !controlsAreDisabled else { return }
		if isPlaying {
			pauseFromUserAction()
		} else {
			isManuallyPaused = false
			playbackIntent = .playing
			isChangingPlayback = true
			nowPlaying.updatePlayback(isPlaying: true)
			performFadeIn(isUserInitiated: true)
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
		guard let source = model.parsedYouTubeSource else {
			stopAndClearPlayer()
			Task {
				await model.log.error(
					"Background music failed: invalid YouTube URL (\(model.launcherMusicURL))"
				)
			}
			return
		}

		loadingTask?.cancel()
		controlTask?.cancel()
		shuffleTask?.cancel()
		fadeTask?.cancel()
		volumeTask?.cancel()
		controlTask = nil
		shuffleTask = nil
		fadeTask = nil
		volumeTask = nil
		activeControlID = nil
		activeFadeID = nil
		isChangingTrack = false
		isChangingPlayback = false
		playbackIntent = nil
		didShuffleCurrentPlaylist = false
		cancellables.removeAll()
		currentSource = source
		isManuallyPaused = false

		if let player {
			setupObservation(for: player, source: source)
			loadingTask = Task { [weak self] in
				guard let self else { return }
				do {
					if player.source == nil || player.source != source {
						try await player.load(source: source)
					}
					guard !Task.isCancelled else { return }
					await model.log.info("Background music loaded source: \(source)")
					performFadeIn(on: player)
				} catch {
					guard !Task.isCancelled else { return }
					await model.log.error(
						"Background music failed to load source: \(error.localizedDescription)"
					)
				}
				loadingTask = nil
			}
			return
		}

		let newPlayer = YouTubePlayer(
			source: source,
			parameters: .init(
				autoPlay: true,
				showControls: false,
				restrictRelatedVideosToSameChannel: false
			)
		)
		Task { [log = model.log] in
			await log.info("Background music initializing player with source: \(source)")
		}
		player = newPlayer
		setupObservation(for: newPlayer, source: source)
	}

	private func setupObservation(for targetPlayer: YouTubePlayer, source: YouTubePlayer.Source) {
		lastObservedTitle = nil
		lastObservedVideoID = nil
		playbackState = nil

		targetPlayer.playbackStatePublisher
			.receive(on: DispatchQueue.main)
			.removeDuplicates()
			.sink { [weak self, weak targetPlayer] state in
				guard let self, let targetPlayer, self.player === targetPlayer else { return }
				playbackState = state
				reconcilePlaybackIntent(with: state)
				nowPlaying.updatePlayback(isPlaying: isPlaying)
				Task { [log = model.log] in
					await log.debug("Background music state: \(state)")
				}

				if state == .cued || state == .unstarted {
					if model.playsLauncherMusic
						&& !model.isGameProcessRunning
						&& !isManuallyPaused
					{
						performFadeIn(on: targetPlayer)
					}
				}

				if state == .playing,
					case .playlist = source,
					!didShuffleCurrentPlaylist
				{
					didShuffleCurrentPlaylist = true
					shuffleInitialPlaylist(on: targetPlayer)
				}
			}
			.store(in: &cancellables)

		targetPlayer.playbackMetadataPublisher
			.receive(on: DispatchQueue.main)
			.sink { [weak self, weak targetPlayer] metadata in
				guard let self, let targetPlayer, self.player === targetPlayer else { return }
				applyTrackTitle(from: metadata)
			}
			.store(in: &cancellables)
	}

}

enum PlaybackIntent {
	case playing
	case paused
}
