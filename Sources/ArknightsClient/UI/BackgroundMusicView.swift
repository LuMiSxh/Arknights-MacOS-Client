// SPDX-License-Identifier: MPL-2.0

import Combine
import SwiftUI
import YouTubePlayerKit

/// Plays background music using YouTubePlayerKit, with smooth volume fading,
/// playlist shuffling, track title inspection, and game lifecycle pausing.
struct BackgroundMusicView: View {
	@Bindable var model: LauncherViewModel

	@State private var player: YouTubePlayer?
	@State private var cancellables: Set<AnyCancellable> = []
	@State private var didShuffleCurrentPlaylist = false
	@State private var fadeTask: Task<Void, Never>?
	@State private var lastObservedTitle: String?

	var body: some View {
		Group {
			// Keep the WebKit view mounted as long as music is enabled in preferences,
			// even when the game is running. Unmounting it would dismantle the WKWebView
			// and lose playlist position/timestamp when resuming after gameplay.
			if let player, model.playsLauncherMusic {
				YouTubePlayerView(player)
					.frame(
						width: AppConstants.Music.backgroundMusicViewFrame,
						height: AppConstants.Music.backgroundMusicViewFrame
					)
					.opacity(AppConstants.Music.backgroundMusicOpacity)
					.allowsHitTesting(false)
			}
		}
		.onAppear {
			if model.phase != .checking
				&& model.playsLauncherMusic
				&& !model.isGameProcessRunning
			{
				setupPlayer()
			}
		}
		.onChange(of: model.phase) { oldPhase, newPhase in
			if oldPhase == .checking
				&& newPhase != .checking
				&& model.playsLauncherMusic
				&& !model.isGameProcessRunning
			{
				if player == nil {
					setupPlayer()
				}
			}
		}
		.onChange(of: model.launcherMusicURL) { _, _ in
			if model.playsLauncherMusic && !model.isGameProcessRunning {
				setupPlayer()
			}
		}
		.onChange(of: model.playsLauncherMusic) { _, isPlaying in
			if isPlaying {
				setupPlayer()
			} else {
				stopAndClearPlayer()
			}
		}
		.onChange(of: model.launcherMusicVolume) { _, newVolume in
			if fadeTask == nil {
				applyVolume(newVolume)
			}
		}
		.onChange(of: model.isGameProcessRunning) { _, isRunning in
			if isRunning {
				performFadeOut()
			} else if model.playsLauncherMusic {
				if player == nil {
					setupPlayer()
				} else {
					performFadeIn()
				}
			}
		}
		.onDisappear {
			stopAndClearPlayer()
		}
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

		didShuffleCurrentPlaylist = false
		cancellables.removeAll()

		if let player {
			Task { [log = model.log] in
				await log.info("Background music loading source: \(source)")
			}
			setupObservation(for: player, source: source)

			Task {
				if player.source == nil || player.source != source {
					try? await player.load(source: source)
				}
				performFadeIn(on: player)
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

		setupObservation(for: newPlayer, source: source)
		self.player = newPlayer
	}

	private func setupObservation(for targetPlayer: YouTubePlayer, source: YouTubePlayer.Source) {
		lastObservedTitle = nil

		// The YouTube IFrame API is known to re-fire the same state transition (and the
		// same metadata) more than once in a row; `removeDuplicates()` collapses those so
		// a repeated `.cued`/`.unstarted` doesn't restart the fade-in task mid-fade.
		targetPlayer.playbackStatePublisher
			.receive(on: DispatchQueue.main)
			.removeDuplicates()
			.sink { state in
				Task { [log = model.log] in
					await log.debug("Background music state: \(state)")
				}

				if state == .cued || state == .unstarted {
					if model.playsLauncherMusic && !model.isGameProcessRunning {
						performFadeIn(on: targetPlayer)
					}
				}

				if state == .playing {
					// 1. Shuffle & jump to random track once on initial load
					if case .playlist = source, !didShuffleCurrentPlaylist {
						didShuffleCurrentPlaylist = true
						Task {
							try? await targetPlayer.setShufflePlaylist(enabled: true)
							try? await Task.sleep(for: AppConstants.Music.playlistShuffleDelay)
							try? await targetPlayer.nextVideoInPlaylist()
							await model.log.info(
								"Background music playlist shuffled and jumped to random track"
							)
							// The metadata publisher doesn't reliably re-fire right after a
							// playlist jump, so pull the new track's title directly instead
							// of only waiting on the push subscription below.
							if let metadata = try? await targetPlayer.getPlaybackMetadata() {
								applyTrackTitle(from: metadata)
							}
						}
					}
				}
			}
			.store(in: &cancellables)

		// Metadata events provide the active track title for every transition without retries.
		targetPlayer.playbackMetadataPublisher
			.receive(on: DispatchQueue.main)
			.sink { metadata in applyTrackTitle(from: metadata) }
			.store(in: &cancellables)
	}

	private func applyTrackTitle(from metadata: YouTubePlayer.PlaybackMetadata) {
		guard let titleRaw = metadata.title else {
			return
		}
		let title = titleRaw.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !title.isEmpty, title != AppConstants.Music.skipMetadataPlaceholderTitle,
			title != lastObservedTitle
		else {
			return
		}
		lastObservedTitle = title

		model.currentMusicTitle = title
		model.currentMusicVideoID = metadata.videoId
		Task { [log = model.log] in
			await log.info("Background music now playing: \(title)")
		}
	}

	private func performFadeOut() {
		fadeTask?.cancel()
		fadeTask = Task {
			let startVolume = model.launcherMusicVolume
			let steps = AppConstants.Music.fadeSteps
			let stepInterval = AppConstants.Music.fadeOutDuration / Double(steps)

			for i in stride(from: steps, through: 0, by: -1) {
				if Task.isCancelled { return }
				let fraction = Double(i) / Double(steps)
				applyVolume(startVolume * fraction)
				try? await Task.sleep(for: .seconds(stepInterval))
			}

			try? await player?.pause()
			await model.log.info("Background music faded out and paused")
			fadeTask = nil
		}
	}

	private func performFadeIn(on targetPlayer: YouTubePlayer? = nil) {
		fadeTask?.cancel()
		fadeTask = Task {
			let target = targetPlayer ?? player
			guard let target else { return }

			let targetVolume = model.launcherMusicVolume
			let steps = AppConstants.Music.fadeSteps
			let stepInterval = AppConstants.Music.fadeInDuration / Double(steps)

			applyVolume(0, on: target)
			try? await target.play()
			await model.log.info("Background music resuming with fade-in")

			for i in 1...steps {
				if Task.isCancelled { return }
				let fraction = Double(i) / Double(steps)
				applyVolume(targetVolume * fraction, on: target)
				try? await Task.sleep(for: .seconds(stepInterval))
			}

			applyVolume(targetVolume, on: target)
			fadeTask = nil
		}
	}

	private func stopAndClearPlayer() {
		fadeTask?.cancel()
		fadeTask = nil
		cancellables.removeAll()
		Task {
			try? await player?.pause()
			await model.log.info("Background music stopped")
		}
		player = nil
		model.currentMusicTitle = nil
	}

	private func applyVolume(_ volume: Double, on targetPlayer: YouTubePlayer? = nil) {
		guard let playerToUse = targetPlayer ?? player else { return }
		let normalizedVolume = max(0, min(100, Int(volume * 100)))
		Task {
			try? await playerToUse.evaluate(
				javaScript: .youTubePlayer(
					functionName: "setVolume",
					parameters: [normalizedVolume]
				)
			)
		}
	}
}
