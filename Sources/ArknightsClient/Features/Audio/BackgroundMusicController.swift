// SPDX-License-Identifier: MPL-2.0

import Combine
import Foundation
import Observation
import YouTubePlayerKit

@MainActor
protocol BackgroundMusicContext: AnyObject {
	var phase: LauncherPhase { get }
	var isGameProcessRunning: Bool { get }
	var playsLauncherMusic: Bool { get }
	var launcherMusicVolume: Double { get }
	var launcherMusicURL: String { get }
	var parsedYouTubeSource: YouTubePlayer.Source? { get }
	var currentMusicTitle: String? { get set }
	var currentMusicVideoID: String? { get set }
	var log: LauncherLog { get }
	var launcherIconManager: LauncherIconManager { get }
}

/// Owns the hidden YouTube player and coordinates launcher, game, and user playback actions.
@MainActor
@Observable
final class BackgroundMusicController {
	var player: YouTubePlayer?
	var playbackState: YouTubePlayer.PlaybackState?
	var isMuted = false
	var operation: BackgroundMusicOperation = .idle
	var playbackExpectation: BackgroundMusicPlaybackExpectation?

	let context: any BackgroundMusicContext
	let nowPlaying: NowPlayingCoordinator
	var currentSource: YouTubePlayer.Source?
	var isManuallyPaused = false
	@ObservationIgnored var cancellables: Set<AnyCancellable> = []
	@ObservationIgnored var didShuffleCurrentPlaylist = false
	@ObservationIgnored var fadeTask: Task<Void, Never>?
	@ObservationIgnored var loadingTask: Task<Void, Never>?
	@ObservationIgnored var controlTask: Task<Void, Never>?
	@ObservationIgnored var shuffleTask: Task<Void, Never>?
	@ObservationIgnored var volumeTask: Task<Void, Never>?
	@ObservationIgnored var playerGeneration = UUID()
	@ObservationIgnored var fadeOperation: BackgroundMusicFadeOperation?
	@ObservationIgnored var lastObservedTitle: String?
	@ObservationIgnored var lastObservedVideoID: String?

	init(context: any BackgroundMusicContext) {
		self.context = context
		nowPlaying = NowPlayingCoordinator(icon: context.launcherIconManager.currentIcon)
		context.launcherIconManager.iconDidChange = { [weak self] icon in
			self?.nowPlaying.updateArtwork(icon)
		}
	}

	var isPlaying: Bool {
		if let playbackIntent { return playbackIntent == .playing }
		return playbackState == .playing || playbackState == .buffering
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

	var controlsAreDisabled: Bool {
		return player == nil || context.isGameProcessRunning || isChangingTrack
			|| isChangingPlayback
	}

	var effectiveVolume: Double {
		isMuted ? 0 : context.launcherMusicVolume
	}

	func startIfNeeded() {
		guard context.phase != .checking,
			context.playsLauncherMusic,
			!context.isGameProcessRunning
		else { return }
		setupPlayer()
	}

	func phaseDidChange(from oldPhase: LauncherPhase, to newPhase: LauncherPhase) {
		guard oldPhase == .checking, newPhase != .checking, player == nil else { return }
		startIfNeeded()
	}

	func sourceDidChange() {
		guard context.playsLauncherMusic, !context.isGameProcessRunning else { return }
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
		scheduleVolumeUpdate(to: isMuted ? 0 : volume)
	}

	func toggleMute() {
		isMuted.toggle()
		cancelFade()
		scheduleVolumeUpdate(to: effectiveVolume)
	}

	func gameRunningDidChange(to isRunning: Bool) {
		if isRunning {
			performFadeOut()
		} else if context.playsLauncherMusic, !isManuallyPaused {
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
			guard let player else { return }
			let operation = beginOperation(.playbackChange(.playing), on: player)
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
		guard let source = context.parsedYouTubeSource else {
			stopAndClearPlayer()
			Task {
				await context.log.error(
					"Background music failed: invalid YouTube URL (\(context.launcherMusicURL))"
				)
			}
			return
		}

		invalidatePlayerTasks()
		didShuffleCurrentPlaylist = false
		cancellables.removeAll()
		currentSource = source
		isManuallyPaused = false

		if let player {
			setupObservation(for: player, source: source)
			let generation = playerGeneration
			loadingTask = Task { [weak self] in
				guard let self else { return }
				do {
					if player.source == nil || player.source != source {
						try await player.load(source: source)
					}
					guard !Task.isCancelled, isCurrent(player, generation: generation) else {
						return
					}
					await context.log.info("Background music loaded source: \(source)")
					performFadeIn(on: player)
				} catch {
					guard !Task.isCancelled, isCurrent(player, generation: generation) else {
						return
					}
					await context.log.error(
						"Background music failed to load source: \(error.localizedDescription)"
					)
				}
				guard isCurrent(player, generation: generation) else { return }
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
		Task { [log = context.log] in
			await log.info("Background music initializing player with source: \(source)")
		}
		player = newPlayer
		setupObservation(for: newPlayer, source: source)
	}

	private func setupObservation(for targetPlayer: YouTubePlayer, source: YouTubePlayer.Source) {
		let generation = playerGeneration
		lastObservedTitle = nil
		lastObservedVideoID = nil
		playbackState = nil

		targetPlayer.playbackStatePublisher
			.receive(on: DispatchQueue.main)
			.removeDuplicates()
			.sink { [weak self, weak targetPlayer] state in
				guard let self, let targetPlayer, isCurrent(targetPlayer, generation: generation)
				else {
					return
				}
				playbackState = state
				reconcilePlaybackIntent(with: state)
				nowPlaying.updatePlayback(isPlaying: isPlaying)
				Task { [log = context.log] in
					await log.debug("Background music state: \(state)")
				}

				if state == .cued || state == .unstarted {
					if context.playsLauncherMusic
						&& !context.isGameProcessRunning
						&& !isManuallyPaused
					{
						performFadeIn(on: targetPlayer)
					}
				}

				if state == .playing, case .playlist = source {
					shuffleInitialPlaylistIfNeeded(on: targetPlayer)
				}
			}
			.store(in: &cancellables)

		targetPlayer.playbackMetadataPublisher
			.receive(on: DispatchQueue.main)
			.sink { [weak self, weak targetPlayer] metadata in
				guard let self, let targetPlayer, isCurrent(targetPlayer, generation: generation)
				else {
					return
				}
				applyTrackTitle(from: metadata)
			}
			.store(in: &cancellables)
	}

}
