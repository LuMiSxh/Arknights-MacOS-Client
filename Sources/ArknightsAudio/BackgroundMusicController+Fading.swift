// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import YouTubePlayerKit

extension BackgroundMusicController {
	func performFadeOut() {
		guard let player else { return }
		if case .playbackChange(let playbackOperation, .playing) = operation {
			finishOperation(playbackOperation)
		}
		expectPlayback(.paused)
		volumeSlot.invalidate()
		let generation = playerGeneration
		fadeTask = fadeSlot.replace { [weak self] token in
			guard let self else { return }
			let startVolume = effectiveVolume
			let steps = AppConstants.Music.fadeSteps
			let stepInterval = AppConstants.Music.fadeOutDuration / Double(steps)
			let volumes = stride(from: steps, through: 0, by: -1).map {
				startVolume * Double($0) / Double(steps)
			}
			let completed = await ramp(
				through: volumes,
				on: player,
				generation: generation,
				stepInterval: stepInterval,
				token: token
			)
			guard completed else { return }

			do {
				guard fadeSlot.owns(token) else { return }
				try await playerCommands.pause(player)
				guard fadeSlot.owns(token) else { return }
				lifecycle.log.info("Background music faded out and paused")
			} catch {
				guard fadeSlot.owns(token) else { return }
				lifecycle.log.error(
					"Background music failed to pause after fading out: \(error.localizedDescription)"
				)
			}
			finishFade(token)
		}
	}

	func performFadeIn(
		on targetPlayer: YouTubePlayer? = nil,
		userPlaybackOperation: TaskSlot.Token? = nil
	) {
		volumeSlot.invalidate()
		guard let target = targetPlayer ?? player else { return }
		let expectation = expectPlayback(.playing)
		let generation = playerGeneration
		fadeTask = fadeSlot.replace { [weak self] token in
			guard let self else { return }

			let targetVolume = effectiveVolume
			let steps = AppConstants.Music.fadeSteps
			let stepInterval = AppConstants.Music.fadeInDuration / Double(steps)

			guard fadeSlot.owns(token) else { return }
			await applyVolume(0, on: target, generation: generation)
			do {
				guard fadeSlot.owns(token) else { return }
				try await playerCommands.play(target)
				guard fadeSlot.owns(token) else { return }
				if let userPlaybackOperation {
					finishOperation(userPlaybackOperation)
				}
				lifecycle.log.info("Background music resuming with fade-in")
				guard fadeSlot.owns(token) else { return }
				shuffleInitialPlaylistIfNeeded(on: target)
			} catch {
				guard fadeSlot.owns(token) else { return }
				if let userPlaybackOperation {
					finishOperation(userPlaybackOperation)
				}
				clearPlaybackExpectation(expectation)
				lifecycle.log.error(
					"Background music failed to resume: \(error.localizedDescription)"
				)
				finishFade(token)
				return
			}

			let volumes = (1...steps).map { targetVolume * Double($0) / Double(steps) }
			let completed = await ramp(
				through: volumes,
				on: target,
				generation: generation,
				stepInterval: stepInterval,
				token: token
			)
			guard completed else { return }

			guard fadeSlot.owns(token) else { return }
			await applyVolume(targetVolume, on: target, generation: generation)
			finishFade(token)
		}
	}

	func stopAndClearPlayer() {
		let playerToStop = player
		sourceChangeTask?.cancel()
		sourceChangeTask = nil
		invalidatePlayerTasks()
		cancellables.removeAll()
		player = nil
		playbackState = nil
		currentSource = nil
		lastObservedTitle = nil
		lastObservedVideoID = nil
		currentMusicTitle = nil
		currentMusicVideoID = nil
		nowPlaying.clear()

		Task { [log = lifecycle.log] in
			do {
				try await playerToStop?.pause()
				log.info("Background music stopped")
			} catch {
				log.error(
					"Background music failed to stop cleanly: \(error.localizedDescription)"
				)
			}
		}
	}

	func applyVolume(
		_ volume: Double,
		on playerToUse: YouTubePlayer,
		generation: TaskSlot.Token
	) async {
		guard isCurrent(playerToUse, generation: generation) else { return }
		let normalizedVolume = max(0, min(100, Int(volume * 100)))
		do {
			try await playerCommands.setVolume(playerToUse, normalizedVolume)
		} catch {
			guard !Task.isCancelled, isCurrent(playerToUse, generation: generation) else { return }
			lifecycle.log.debug(
				"Background music volume update was not applied: \(error.localizedDescription)"
			)
		}
	}

	// Returns `false` when the fade is superseded or cancelled.
	private func ramp(
		through volumes: [Double],
		on player: YouTubePlayer,
		generation: TaskSlot.Token,
		stepInterval: Double,
		token: TaskSlot.Token
	) async -> Bool {
		for volume in volumes {
			guard fadeSlot.owns(token) else { return false }
			await applyVolume(volume, on: player, generation: generation)
			do {
				try await Task.sleep(
					for: .seconds(stepInterval),
					tolerance: .seconds(stepInterval / 10)
				)
			} catch {
				return false
			}
		}
		return true
	}

	func finishFade(_ token: TaskSlot.Token) {
		guard fadeSlot.owns(token) else { return }
		cancelFade()
	}
}
