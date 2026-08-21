// SPDX-License-Identifier: MPL-2.0

import Foundation
import YouTubePlayerKit

extension BackgroundMusicController {
	func shuffleInitialPlaylist(on targetPlayer: YouTubePlayer) {
		shuffleTask?.cancel()
		let operation = beginOperation(.trackChange, on: targetPlayer)
		shuffleTask = Task { [weak self] in
			guard let self else { return }
			do {
				guard isCurrent(operation) else { return }
				try await targetPlayer.setLoopPlaylist(enabled: true)
				guard isCurrent(operation) else { return }
				try await targetPlayer.setShufflePlaylist(enabled: true)
				try await Task.sleep(for: AppConstants.Music.playlistShuffleDelay)
				guard isCurrent(operation) else { return }
				let changed = try await selectTrack(
					on: targetPlayer,
					operation: operation,
					direction: .next,
					expectsPlayback: true
				)
				if changed {
					await context.log.info(
						"Background music playlist shuffled and started a random track"
					)
				} else {
					await context.log.error(
						"Background music playlist shuffled, but the selected track did not start"
					)
				}
			} catch {
				guard !Task.isCancelled, isCurrent(operation) else { return }
				await context.log.error(
					"Background music failed to shuffle the playlist: \(error.localizedDescription)"
				)
			}
			guard isCurrent(operation) else { return }
			finishOperation(operation)
			shuffleTask = nil
		}
	}

	func pauseFromUserAction() {
		guard let player else { return }
		isManuallyPaused = true
		let operation = beginOperation(.playbackChange(.paused), on: player)
		playbackExpectation = .init(token: operation, intent: .paused)
		nowPlaying.updatePlayback(isPlaying: false)
		cancelFade()
		controlTask = Task { [weak self] in
			guard let self else { return }
			do {
				guard isCurrent(operation) else { return }
				try await player.pause()
				guard isCurrent(operation) else { return }
				await context.log.info("Background music paused by user")
			} catch {
				guard !Task.isCancelled, isCurrent(operation) else { return }
				clearPlaybackExpectation(for: operation)
				await context.log.error(
					"Background music failed to pause: \(error.localizedDescription)"
				)
			}
			guard isCurrent(operation) else { return }
			finishOperation(operation)
			controlTask = nil
		}
	}

	func changeTrack(direction: TrackDirection) {
		guard canNavigatePlaylist, !controlsAreDisabled, let player else { return }
		let previousVideoID = context.currentMusicVideoID
		let expectsPlayback = !isManuallyPaused
		let operation = beginOperation(.trackChange, on: player)
		controlTask = Task { [weak self] in
			guard let self else { return }
			do {
				let changed = try await selectTrack(
					on: player,
					operation: operation,
					direction: direction,
					previousVideoID: previousVideoID,
					expectsPlayback: expectsPlayback
				)
				if changed {
					await context.log.info(
						"Background music started the \(direction.logName) track"
					)
				} else {
					await context.log.error(
						"Background music did not start the \(direction.logName) track"
					)
				}
			} catch {
				guard !Task.isCancelled, isCurrent(operation) else { return }
				await context.log.error(
					"Background music failed to select the \(direction.logName) track: \(error.localizedDescription)"
				)
			}
			guard isCurrent(operation) else { return }
			finishOperation(operation)
			controlTask = nil
		}
	}

	private func selectTrack(
		on targetPlayer: YouTubePlayer,
		operation: BackgroundMusicOperationToken,
		direction: TrackDirection,
		previousVideoID: String? = nil,
		expectsPlayback: Bool
	) async throws -> Bool {
		guard isCurrent(operation) else { return false }
		guard let playlist = try await targetPlayer.getPlaylist(), !playlist.isEmpty else {
			await context.log.error("Background music playlist is empty or unavailable")
			return false
		}
		let currentIndex = try await targetPlayer.getPlaylistIndex()
		guard isCurrent(operation) else { return false }
		guard
			let targetIndex = direction.targetIndex(
				in: playlist,
				currentIndex: currentIndex
			)
		else {
			await context.log.error(
				"Background music playlist has no different playable track; count=\(playlist.count) index=\(currentIndex)"
			)
			return false
		}
		let resolvedPreviousVideoID =
			previousVideoID
			?? (playlist.indices.contains(currentIndex) ? playlist[currentIndex] : nil)
		let targetVideoID = playlist[targetIndex]
		playbackState = nil
		try await targetPlayer.playVideoInPlaylist(at: targetIndex)
		guard isCurrent(operation) else { return false }
		return await waitForTrackStart(
			on: targetPlayer,
			operation: operation,
			targetIndex: targetIndex,
			targetVideoID: targetVideoID,
			previousVideoID: resolvedPreviousVideoID,
			expectsPlayback: expectsPlayback
		)
	}

	private func waitForTrackStart(
		on targetPlayer: YouTubePlayer,
		operation: BackgroundMusicOperationToken,
		targetIndex: Int,
		targetVideoID: String,
		previousVideoID: String?,
		expectsPlayback: Bool
	) async -> Bool {
		var pausedChangedTrack = false
		var lastIndex: Int?
		var lastVideoID: String?
		var lastState: YouTubePlayer.PlaybackState?
		var lastError: String?
		for _ in 0..<AppConstants.Music.trackChangePollLimit {
			guard !Task.isCancelled, isCurrent(operation) else { return false }
			do {
				let observedIndex = try await targetPlayer.getPlaylistIndex()
				guard isCurrent(operation) else { return false }
				lastIndex = observedIndex
				guard observedIndex == targetIndex else {
					try await Task.sleep(for: AppConstants.Music.trackChangePollInterval)
					continue
				}

				let metadata = try await targetPlayer.getPlaybackMetadata()
				guard isCurrent(operation) else { return false }
				lastVideoID = metadata.videoId
				lastState = playbackState
				// YouTube applies `setShuffle` asynchronously. The selected index remains
				// authoritative even if its video changed after our shuffled-list snapshot.
				let reachedTarget = Self.hasReachedSelectedVideo(
					previousVideoID: previousVideoID,
					expectedVideoID: targetVideoID,
					observedVideoID: metadata.videoId
				)
				let hasValidTitle = reachedTarget && applyTrackTitle(from: metadata)
				let reachedExpectedState =
					expectsPlayback
					? playbackState == .playing
					: playbackState == .paused
				if reachedTarget, !expectsPlayback, !pausedChangedTrack {
					try await targetPlayer.pause()
					pausedChangedTrack = true
					continue
				}
				if reachedTarget, hasValidTitle, reachedExpectedState { return true }
			} catch {
				lastError = error.localizedDescription
			}
			do {
				try await Task.sleep(for: AppConstants.Music.trackChangePollInterval)
			} catch {
				return false
			}
		}
		guard isCurrent(operation) else { return false }
		if lastIndex == targetIndex {
			let resolvedVideoID =
				lastVideoID.map {
					previousVideoID == nil || $0 != previousVideoID ? $0 : targetVideoID
				}
				?? targetVideoID
			context.currentMusicVideoID = resolvedVideoID
			if lastObservedVideoID != resolvedVideoID {
				let fallbackTitle = "Playlist track \(targetIndex + 1)"
				context.currentMusicTitle = fallbackTitle
				nowPlaying.updateTrack(title: fallbackTitle, artist: nil)
			}
		}
		let previous = previousVideoID ?? "unknown"
		let observedIndex = lastIndex.map(String.init) ?? "unknown"
		let observedVideoID = lastVideoID ?? "unknown"
		let observedState = lastState.map(String.init(describing:)) ?? "unknown"
		let errorDetail = lastError.map { " error=\($0)" } ?? ""
		await context.log.error(
			"Background music timed out waiting for target; previous=\(previous) targetIndex=\(targetIndex) targetVideo=\(targetVideoID) observedIndex=\(observedIndex) observedVideo=\(observedVideoID) state=\(observedState)\(errorDetail)"
		)
		return false
	}

	static func hasReachedSelectedVideo(
		previousVideoID: String?,
		expectedVideoID: String,
		observedVideoID: String?
	) -> Bool {
		guard let observedVideoID else { return false }
		return observedVideoID == expectedVideoID
			|| previousVideoID.map { observedVideoID != $0 } == true
	}

	func reconcilePlaybackIntent(with state: YouTubePlayer.PlaybackState) {
		guard let playbackExpectation, isCurrent(playbackExpectation.token) else { return }
		let reachedIntent =
			switch playbackExpectation.intent {
			case .playing: state == .playing || state == .buffering
			case .paused: state == .paused
			}
		guard reachedIntent else { return }
		clearPlaybackExpectation(for: playbackExpectation.token)
		finishOperation(playbackExpectation.token)
	}

	@discardableResult
	func applyTrackTitle(from metadata: YouTubePlayer.PlaybackMetadata) -> Bool {
		guard let titleRaw = metadata.title else { return false }
		let title = titleRaw.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !title.isEmpty, title != AppConstants.Music.skipMetadataPlaceholderTitle else {
			return false
		}

		context.currentMusicVideoID = metadata.videoId
		nowPlaying.updateTrack(title: title, artist: metadata.author)
		let changed = title != lastObservedTitle || metadata.videoId != lastObservedVideoID
		lastObservedTitle = title
		lastObservedVideoID = metadata.videoId
		context.currentMusicTitle = title
		guard changed else { return true }
		Task { [log = context.log] in
			await log.info("Background music now playing: \(title)")
		}
		return true
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

	func targetIndex(in playlist: [String], currentIndex: Int) -> Int? {
		guard playlist.indices.contains(currentIndex), playlist.count > 1 else { return nil }
		let currentVideoID = playlist[currentIndex]
		for distance in 1..<playlist.count {
			let candidate =
				switch self {
				case .previous:
					(currentIndex - distance + playlist.count) % playlist.count
				case .next:
					(currentIndex + distance) % playlist.count
				}
			if playlist[candidate] != currentVideoID { return candidate }
		}
		return nil
	}
}
