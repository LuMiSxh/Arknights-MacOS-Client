// SPDX-License-Identifier: MPL-2.0

import Foundation
import YouTubePlayerKit

extension BackgroundMusicController {
	func shuffleInitialPlaylist(on targetPlayer: YouTubePlayer) {
		shuffleTask?.cancel()
		isChangingTrack = true
		shuffleTask = Task { [weak self] in
			guard let self else { return }
			do {
				let currentMetadata = try? await targetPlayer.getPlaybackMetadata()
				let previousVideoID = model.currentMusicVideoID ?? currentMetadata?.videoId
				try await targetPlayer.setShufflePlaylist(enabled: true)
				try await Task.sleep(for: AppConstants.Music.playlistShuffleDelay)
				guard player === targetPlayer else { return }
				try await targetPlayer.nextVideoInPlaylist()
				_ = await waitForTrackChange(
					on: targetPlayer,
					previousVideoID: previousVideoID,
					expectsPlayback: true
				)
				await model.log.info(
					"Background music playlist shuffled and jumped to random track"
				)
			} catch {
				guard !Task.isCancelled else { return }
				await model.log.error(
					"Background music failed to shuffle the playlist: \(error.localizedDescription)"
				)
			}
			guard player === targetPlayer else { return }
			isChangingTrack = false
			shuffleTask = nil
		}
	}

	func pauseFromUserAction() {
		guard let player else { return }
		isManuallyPaused = true
		playbackIntent = .paused
		isChangingPlayback = true
		fadeTask?.cancel()
		fadeTask = nil
		activeFadeID = nil
		controlTask?.cancel()
		let controlID = UUID()
		activeControlID = controlID
		controlTask = Task { [weak self] in
			guard let self else { return }
			do {
				try await player.pause()
				await model.log.info("Background music paused by user")
			} catch {
				guard !Task.isCancelled else { return }
				playbackIntent = nil
				await model.log.error(
					"Background music failed to pause: \(error.localizedDescription)"
				)
			}
			guard activeControlID == controlID else { return }
			isChangingPlayback = false
			activeControlID = nil
			controlTask = nil
		}
	}

	func changeTrack(direction: TrackDirection) {
		guard canNavigatePlaylist, !controlsAreDisabled, let player else { return }
		isChangingTrack = true
		let previousVideoID = model.currentMusicVideoID
		let expectsPlayback = !isManuallyPaused
		controlTask?.cancel()
		let controlID = UUID()
		activeControlID = controlID
		controlTask = Task { [weak self] in
			guard let self else { return }
			do {
				switch direction {
				case .previous:
					try await player.previousVideoInPlaylist()
				case .next:
					try await player.nextVideoInPlaylist()
				}
				_ = await waitForTrackChange(
					on: player,
					previousVideoID: previousVideoID,
					expectsPlayback: expectsPlayback
				)
				await model.log.info("Background music selected the \(direction.logName) track")
			} catch {
				guard !Task.isCancelled else { return }
				await model.log.error(
					"Background music failed to select the \(direction.logName) track: \(error.localizedDescription)"
				)
			}
			guard activeControlID == controlID else { return }
			isChangingTrack = false
			activeControlID = nil
			controlTask = nil
		}
	}

	func waitForTrackChange(
		on targetPlayer: YouTubePlayer,
		previousVideoID: String?,
		expectsPlayback: Bool
	) async -> Bool {
		var pausedChangedTrack = false
		for _ in 0..<AppConstants.Music.playerStatePollLimit {
			guard !Task.isCancelled, player === targetPlayer else { return false }
			do {
				let metadata = try await targetPlayer.getPlaybackMetadata()
				let state = try await targetPlayer.getPlaybackState()
				guard player === targetPlayer else { return false }
				playbackState = state
				let hasChangedTrack =
					metadata.videoId.map {
						previousVideoID == nil || $0 != previousVideoID
					} ?? false
				let reachedExpectedState =
					expectsPlayback
					? state == .playing
					: state == .paused
				if hasChangedTrack {
					applyTrackTitle(from: metadata)
				}
				if hasChangedTrack, !expectsPlayback, !pausedChangedTrack {
					try await targetPlayer.pause()
					pausedChangedTrack = true
					continue
				}
				if hasChangedTrack, reachedExpectedState { return true }
			} catch {
				// The embedded player commonly rejects reads while replacing a video; retry
				// until its metadata and playback state become coherent again.
			}
			try? await Task.sleep(for: AppConstants.Music.playerStatePollInterval)
		}
		await model.log.error("Background music timed out waiting for the selected track")
		return false
	}

	func reconcilePlaybackIntent(with state: YouTubePlayer.PlaybackState) {
		let reachedIntent =
			switch playbackIntent {
			case .playing: state == .playing || state == .buffering
			case .paused: state == .paused
			case nil: false
			}
		guard reachedIntent else { return }
		playbackIntent = nil
		isChangingPlayback = false
	}

	func applyTrackTitle(from metadata: YouTubePlayer.PlaybackMetadata) {
		guard let titleRaw = metadata.title else { return }
		let title = titleRaw.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !title.isEmpty, title != AppConstants.Music.skipMetadataPlaceholderTitle else {
			return
		}

		model.currentMusicVideoID = metadata.videoId
		guard title != lastObservedTitle else { return }
		lastObservedTitle = title
		model.currentMusicTitle = title
		Task { [log = model.log] in
			await log.info("Background music now playing: \(title)")
		}
	}
}

enum TrackDirection {
	case previous
	case next

	var logName: String {
		switch self {
		case .previous: "previous"
		case .next: "next"
		}
	}
}
