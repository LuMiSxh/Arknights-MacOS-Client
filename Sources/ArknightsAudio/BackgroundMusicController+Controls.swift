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
				lifecycle.log.info(.music, "paused-by-user")
			} catch {
				guard !Task.isCancelled, isCurrent(operation) else { return }
				clearPlaybackExpectation(expectation)
				lifecycle.log.error(.music, "pause-failed", error: error)
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
						.music, "track-changed", ["direction": direction.logName])
				} else {
					lifecycle.log.error(
						.music, "track-change-failed", ["direction": direction.logName])
				}
			} catch {
				guard !Task.isCancelled, isCurrent(operation) else { return }
				lifecycle.log.error(
					.music, "track-select-failed", ["direction": direction.logName],
					error: error)
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
		// The player is the truth: the title state can lag behind the track that actually plays.
		let resolvedPreviousVideoID =
			await readMetadata(of: targetPlayer)?.videoId ?? previousVideoID
		guard isCurrent(operation) else { return false }
		playbackState = nil
		expectPlayback(expectsPlayback ? .playing : .paused)
		// Subscribe before the command so the new track's events cannot be missed.
		let events = playerCommands.events(targetPlayer)
		// YouTube owns the shuffled order, so it picks the neighbour.
		switch direction {
		case .next: try await playerCommands.nextVideo(targetPlayer)
		case .previous: try await playerCommands.previousVideo(targetPlayer)
		}
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
		events: BackgroundMusicPlayerEvents
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
			group.addTask {
				await self.timeOutTrackStart(
					on: targetPlayer,
					previousVideoID: previousVideoID,
					expectsPlayback: expectsPlayback
				)
			}
			if expectsPlayback {
				group.addTask {
					await self.recheckTrackStart(
						on: targetPlayer,
						previousVideoID: previousVideoID
					)
				}
			}
			let started = await group.next() ?? false
			group.cancelAll()
			return started
		}
	}

	/// After the timeout, one last read of the player decides: the events can be lost, the track
	/// can still have changed, and the title must show what plays.
	private func timeOutTrackStart(
		on targetPlayer: YouTubePlayer,
		previousVideoID: String?,
		expectsPlayback: Bool
	) async -> Bool {
		do {
			try await sleep(for: AppConstants.Music.trackStartTimeout)
		} catch {
			return false
		}
		let changed = await videoDiffers(on: targetPlayer, from: previousVideoID)
		guard !(changed && expectsPlayback) else {
			if let state = await readPlaybackState(of: targetPlayer), state == .playing {
				adoptPlaybackState(state, on: targetPlayer)
			}
			return true
		}
		lifecycle.log.error(
			.music, "track-start-timed-out", ["previousVideoId": previousVideoID])
		return false
	}

	/// YouTube can start the new video without ever reporting `.playing`, so after a quiet interval
	/// the player is read directly. No event source covers a lost event, hence the bounded recheck.
	private func recheckTrackStart(
		on targetPlayer: YouTubePlayer,
		previousVideoID: String?
	) async -> Bool {
		// The timeout task ends the wait, so this loop needs no bound of its own.
		while !Task.isCancelled {
			do {
				try await sleep(for: AppConstants.Music.trackStartRecheckInterval)
			} catch {
				return false
			}
			if await videoDiffers(on: targetPlayer, from: previousVideoID),
				await readPlaybackState(of: targetPlayer) == .playing
			{
				adoptPlaybackState(.playing, on: targetPlayer)
				return true
			}
		}
		return false
	}

	/// Returns once a different video plays (or pauses, when the user paused) or the player fails.
	private func observeTrackStart(
		on targetPlayer: YouTubePlayer,
		previousVideoID: String?,
		expectsPlayback: Bool,
		events: BackgroundMusicPlayerEvents
	) async -> Bool {
		var videoChanged = false
		var didPause = false
		var state: YouTubePlayer.PlaybackState?
		for await event in events {
			switch event {
			case .playback(let newState):
				state = newState
			case .metadata:
				break
			case .failure:
				return false
			}
			if !videoChanged {
				// `.metadata` events can be stale or missing, so the player is asked directly.
				guard await videoDiffers(on: targetPlayer, from: previousVideoID)
				else { continue }
				videoChanged = true
			}
			if expectsPlayback {
				// YouTube can skip `.playing` after `.buffering`, so the player's own state decides.
				if state != .playing, let read = await readPlaybackState(of: targetPlayer) {
					state = read
					if read == .playing { adoptPlaybackState(.playing, on: targetPlayer) }
				}
				if state == .playing { return true }
			} else if !didPause {
				didPause = true
				state = nil
				do {
					try await playerCommands.pause(targetPlayer)
				} catch {
					lifecycle.log.error(
						.music, "pause-changed-track-failed", error: error)
					return false
				}
			} else if state == .paused {
				return true
			}
		}
		return false
	}

	/// Reads the playing video from the player and applies its title.
	private func videoDiffers(
		on targetPlayer: YouTubePlayer, from previousVideoID: String?
	) async
		-> Bool
	{
		guard let metadata = await readMetadata(of: targetPlayer) else { return false }
		applyTrackTitle(from: metadata)
		return metadata.videoId != nil && metadata.videoId != previousVideoID
	}

	private func readPlaybackState(
		of targetPlayer: YouTubePlayer
	) async -> YouTubePlayer.PlaybackState? {
		do {
			return try await playerCommands.getPlaybackState(targetPlayer)
		} catch {
			lifecycle.log.warning(.music, "playback-state-read-failed", error: error)
			return nil
		}
	}

	func readMetadata(of targetPlayer: YouTubePlayer) async -> YouTubePlayer.PlaybackMetadata? {
		do {
			return try await playerCommands.getPlaybackMetadata(targetPlayer)
		} catch {
			lifecycle.log.warning(.music, "metadata-read-failed", error: error)
			return nil
		}
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
		let playlist = currentSource?.isPlaylist == true
		lifecycle.log.info(.music, "track-started", ["title": title, "playlist": playlist])
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
}
