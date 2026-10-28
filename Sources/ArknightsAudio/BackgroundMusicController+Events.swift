// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import YouTubePlayerKit

extension BackgroundMusicController {
	func observeEvents(of targetPlayer: YouTubePlayer) {
		let generation = playerGeneration
		lastObservedTitle = nil
		lastObservedVideoID = nil
		playbackState = nil
		let events = playerCommands.events(targetPlayer)
		eventSlot.replace { [weak self, weak targetPlayer] token in
			for await event in events {
				guard let self, let targetPlayer, eventSlot.owns(token),
					isCurrent(targetPlayer, generation: generation)
				else { return }
				handle(event, from: targetPlayer)
			}
		}
	}

	private func handle(_ event: BackgroundMusicPlayerEvent, from targetPlayer: YouTubePlayer) {
		switch event {
		case .playback(let state):
			playbackState = state
			reconcilePlaybackIntent(with: state)
			nowPlaying.updatePlayback(isPlaying: isPlaying)
			lifecycle.log.debug("Background music state: \(state)")
			if state == .playing {
				consecutiveFailures = 0
				transition(.playerPlayed)
				refreshTitle(of: targetPlayer)
			}
			// A playlist is cued, not autoplayed; a video autoplays and only needs a nudge when it stalls.
			let isReadyToStart =
				currentSource?.isPlaylist == true
				? state == .cued : state == .cued || state == .unstarted
			if isReadyToStart, settings.playsLauncherMusic, !lifecycle.activity.hasGameProcess,
				!phase.isUserPaused
			{
				performFadeIn(on: targetPlayer)
			}
		case .metadata(let metadata):
			applyTrackTitle(from: metadata)
		case .failure(let failure):
			handle(failure, on: targetPlayer)
		}
	}

	/// A `videoDataChange` event can arrive before YouTube serves the new video's data, so the
	/// title is also read from the player whenever a track starts playing.
	private func refreshTitle(of targetPlayer: YouTubePlayer) {
		let generation = playerGeneration
		titleSlot.replace { [weak self] token in
			guard let self else { return }
			do {
				let metadata = try await playerCommands.getPlaybackMetadata(targetPlayer)
				guard titleSlot.owns(token), isCurrent(targetPlayer, generation: generation) else {
					return
				}
				applyTrackTitle(from: metadata)
			} catch {
				guard titleSlot.owns(token) else { return }
				lifecycle.log.debug(
					"Background music could not read the track title: \(error.localizedDescription)"
				)
			}
			guard titleSlot.owns(token) else { return }
			titleSlot.invalidate()
		}
	}

	private func handle(_ failure: BackgroundMusicFailure, on targetPlayer: YouTubePlayer) {
		lifecycle.log.error("Background music player failed: \(failure)")
		// A paused or silenced player is not trying to play, and during a game the music is silenced
		// or about to be; a late failure changes nothing.
		guard phase == .playing || phase == .unavailable, !lifecycle.activity.hasGameProcess
		else { return }
		consecutiveFailures += 1
		if failure == .unplayableTrack, canNavigatePlaylist,
			consecutiveFailures < AppConstants.Music.maxConsecutivePlayerFailures
		{
			startTrackChange(direction: .next)
		} else {
			stopBecauseUnavailable(on: targetPlayer)
		}
	}

	private func stopBecauseUnavailable(on targetPlayer: YouTubePlayer) {
		lifecycle.log.error("Background music stopped: the player cannot play the music")
		cancelOperation()
		volumeSlot.invalidate()
		discardPlaybackExpectation()
		transition(.playerFailed)
		// The HUD pill appears only with a title, and it must show that the music is unavailable.
		if currentMusicTitle == nil { currentMusicTitle = "Launcher music" }
		nowPlaying.updatePlayback(isPlaying: false)
		fadeTask = fadeSlot.replace { [weak self] token in
			guard let self else { return }
			do {
				try await playerCommands.pause(targetPlayer)
			} catch {
				guard fadeSlot.owns(token) else { return }
				lifecycle.log.error(
					"Background music failed to pause after the player failed: \(error.localizedDescription)"
				)
			}
			finishFade(token)
		}
	}

	/// Starts the first playlist track at random, or resumes the current track.
	/// Returns `false` when nothing started: a game process exists, or the fade was superseded.
	func startPlayback(on target: YouTubePlayer, token: TaskSlot.Token) async throws -> Bool {
		guard !lifecycle.activity.hasGameProcess else { return false }
		guard currentSource?.isPlaylist == true, !didStartCurrentPlaylist else {
			try await playerCommands.play(target)
			return true
		}
		// YouTube shuffles and loops the playlist from here on; the launcher only picks the start.
		try await playerCommands.setLoop(target, true)
		guard fadeSlot.owns(token) else { return false }
		try await playerCommands.setShuffle(target, true)
		guard fadeSlot.owns(token) else { return false }
		let playlist = try await playerCommands.getPlaylist(target) ?? []
		guard fadeSlot.owns(token), !lifecycle.activity.hasGameProcess else { return false }
		if playlist.isEmpty {
			lifecycle.log.error(
				"Background music playlist is empty or unavailable; playing it in order")
			try await playerCommands.play(target)
		} else {
			try await playerCommands.playVideoInPlaylist(target, randomIndex(playlist.count))
			lifecycle.log.info("Background music playlist started on a random track")
		}
		didStartCurrentPlaylist = true
		return true
	}
}
