// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import YouTubePlayerKit

extension BackgroundMusicController {
	func pauseFromUserAction() {
		guard let player else { return }
		transition(.userPaused)
		let operation = beginOperation(.playbackChange(.paused))
		let expectation = expectPlayback(.paused)
		cancelFade()
		operationTask = Task { [weak self] in
			guard let self else { return }
			do {
				guard isCurrent(operation) else { return }
				try await playerCommands.pause(player)
				guard isCurrent(operation) else { return }
				lifecycle.log.info("Background music paused by user")
			} catch {
				guard !Task.isCancelled, isCurrent(operation) else { return }
				clearPlaybackExpectation(expectation)
				lifecycle.log.error(
					"Background music failed to pause: \(error.localizedDescription)"
				)
			}
			guard isCurrent(operation) else { return }
			finishOperation(operation)
			operationTask = nil
		}
	}

	func changeTrack(direction: TrackDirection) {
		guard canNavigatePlaylist, !controlsAreUnavailable, !isChangingTrack,
			!isChangingPlayback
		else { return }
		startTrackChange(direction: direction)
	}

	/// Replaces any running track or playback change, so a player failure can skip past its track.
	func startTrackChange(direction: TrackDirection) {
		guard let player else { return }
		let previousVideoID = currentMusicVideoID
		let expectsPlayback = !phase.isUserPaused
		let operation = beginOperation(.trackChange)
		operationTask = Task { [weak self] in
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
					lifecycle.log.info(
						"Background music started the \(direction.logName) track"
					)
				} else {
					lifecycle.log.error(
						"Background music did not start the \(direction.logName) track"
					)
				}
			} catch {
				guard !Task.isCancelled, isCurrent(operation) else { return }
				lifecycle.log.error(
					"Background music failed to select the \(direction.logName) track: \(error.localizedDescription)"
				)
			}
			guard isCurrent(operation) else { return }
			finishOperation(operation)
			operationTask = nil
		}
	}

	private func selectTrack(
		on targetPlayer: YouTubePlayer,
		operation: TaskSlot.Token,
		direction: TrackDirection,
		previousVideoID: String?,
		expectsPlayback: Bool
	) async throws -> Bool {
		guard isCurrent(operation) else { return false }
		guard let playlist = try await playerCommands.getPlaylist(targetPlayer), !playlist.isEmpty
		else {
			guard isCurrent(operation) else { return false }
			lifecycle.log.error("Background music playlist is empty or unavailable")
			return false
		}
		guard isCurrent(operation) else { return false }
		let currentIndex = try await playerCommands.getPlaylistIndex(targetPlayer)
		guard isCurrent(operation) else { return false }
		guard
			let targetIndex = direction.targetIndex(
				in: playlist,
				currentIndex: currentIndex
			)
		else {
			lifecycle.log.error(
				"Background music playlist has no different playable track; count=\(playlist.count) index=\(currentIndex)"
			)
			return false
		}
		let resolvedPreviousVideoID =
			previousVideoID
			?? (playlist.indices.contains(currentIndex) ? playlist[currentIndex] : nil)
		playbackState = nil
		expectPlayback(expectsPlayback ? .playing : .paused)
		// Subscribe before the command so the new track's events cannot be missed.
		let events = playerCommands.events(targetPlayer)
		try await playerCommands.playVideoInPlaylist(targetPlayer, targetIndex)
		guard isCurrent(operation) else { return false }
		let started = await waitForTrackStart(
			on: targetPlayer,
			previousVideoID: resolvedPreviousVideoID,
			expectsPlayback: expectsPlayback,
			events: events
		)
		return started && isCurrent(operation)
	}

	private func waitForTrackStart(
		on targetPlayer: YouTubePlayer,
		previousVideoID: String?,
		expectsPlayback: Bool,
		events: AsyncStream<BackgroundMusicPlayerEvent>
	) async -> Bool {
		await withTaskGroup(of: Bool.self) { group in
			group.addTask {
				await self.observeTrackStart(
					on: targetPlayer,
					previousVideoID: previousVideoID,
					expectsPlayback: expectsPlayback,
					events: events
				)
			}
			group.addTask { await self.timeOutTrackStart(previousVideoID: previousVideoID) }
			let started = await group.next() ?? false
			group.cancelAll()
			return started
		}
	}

	/// Always returns `false`, after the timeout or at once when cancelled.
	private func timeOutTrackStart(previousVideoID: String?) async -> Bool {
		do {
			try await sleep(for: AppConstants.Music.trackStartTimeout)
		} catch {
			return false
		}
		lifecycle.log.error(
			"Background music timed out waiting for the next track; previous=\(previousVideoID ?? "unknown")"
		)
		return false
	}

	/// Returns once a different video plays (or pauses, when the user paused) or the player fails.
	private func observeTrackStart(
		on targetPlayer: YouTubePlayer,
		previousVideoID: String?,
		expectsPlayback: Bool,
		events: AsyncStream<BackgroundMusicPlayerEvent>
	) async -> Bool {
		var videoChanged = false
		var didPause = false
		var state: YouTubePlayer.PlaybackState?
		for await event in events {
			switch event {
			case .playback(let newState):
				state = newState
			case .metadata(let metadata):
				if let videoID = metadata.videoId, videoID != previousVideoID {
					videoChanged = true
				}
			case .failure:
				return false
			}
			guard videoChanged else { continue }
			if expectsPlayback {
				if state == .playing { return true }
			} else if !didPause {
				didPause = true
				state = nil
				do {
					try await playerCommands.pause(targetPlayer)
				} catch {
					lifecycle.log.error(
						"Background music failed to pause the changed track: \(error.localizedDescription)"
					)
					return false
				}
			} else if state == .paused {
				return true
			}
		}
		return false
	}

	func reconcilePlaybackIntent(with state: YouTubePlayer.PlaybackState) {
		guard let playbackExpectation, isCurrent(playbackExpectation) else { return }
		let reachedIntent =
			switch playbackExpectation.intent {
			case .playing: state == .playing || state == .buffering
			case .paused: state == .paused
			}
		guard reachedIntent else { return }
		if case .playbackChange(let operation, let intent) = operation,
			intent == playbackExpectation.intent
		{
			finishOperation(operation)
		}
		clearPlaybackExpectation(playbackExpectation)
	}

	@discardableResult
	func applyTrackTitle(from metadata: YouTubePlayer.PlaybackMetadata) -> Bool {
		guard let titleRaw = metadata.title else { return false }
		let title = titleRaw.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !title.isEmpty, title != AppConstants.Music.skipMetadataPlaceholderTitle else {
			return false
		}

		currentMusicVideoID = metadata.videoId
		nowPlaying.updateTrack(title: title, artist: metadata.author)
		let changed = title != lastObservedTitle || metadata.videoId != lastObservedVideoID
		lastObservedTitle = title
		lastObservedVideoID = metadata.videoId
		currentMusicTitle = title
		guard changed else { return true }
		lifecycle.log.info("Background music now playing: \(title)")
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
