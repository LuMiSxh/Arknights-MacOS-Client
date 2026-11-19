// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import YouTubePlayerKit

extension BackgroundMusicController {
	func performFadeOut() {
		// A track change in flight must not select a track after the pause below.
		cancelOperation()
		loadingSlot.invalidate()
		guard let player else { return }
		expectPlayback(.paused)
		volumeSlot.invalidate()
		let generation = playerGeneration
		fadeTask = fadeSlot.replace { [weak self] token in
			guard let self else { return }
			let steps = AppConstants.Music.fadeSteps
			let stepInterval = AppConstants.Music.fadeOutDuration / Double(steps)
			// Mirror of the fade-in curve: YouTube volume is linear, so squaring sounds even.
			let levels = stride(from: steps, through: 0, by: -1).map {
				let remaining = Double($0) / Double(steps)
				return remaining * remaining
			}
			let completed = await ramp(
				levels: levels,
				volume: { [self] in effectiveVolume },
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
		guard !isSilencedForGame, !lifecycle.activity.hasGameProcess,
			let target = targetPlayer ?? player
		else { return }
		let expectation = expectPlayback(.playing)
		let generation = playerGeneration
		fadeTask = fadeSlot.replace { [weak self] token in
			guard let self else { return }

			let steps = AppConstants.Music.fadeSteps
			let stepInterval = AppConstants.Music.fadeInDuration / Double(steps)

			guard fadeSlot.owns(token) else { return }
			await applyVolume(0, on: target, generation: generation)
			do {
				guard fadeSlot.owns(token) else { return }
				let started = try await startPlayback(on: target, token: token)
				guard fadeSlot.owns(token) else { return }
				guard started else {
					if let userPlaybackOperation { finishOperation(userPlaybackOperation) }
					clearPlaybackExpectation(expectation)
					finishFade(token)
					return
				}
				if let userPlaybackOperation {
					finishOperation(userPlaybackOperation)
				}
				lifecycle.log.info("Background music resuming with fade-in")
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

			// The target volume is read at every step so a volume change during the fade is kept.
			let levels = (1...steps).map {
				let progress = Double($0) / Double(steps)
				return progress * progress
			}
			let completed = await ramp(
				levels: levels,
				volume: { [self] in effectiveVolume },
				on: target,
				generation: generation,
				stepInterval: stepInterval,
				token: token
			)
			guard completed else { return }

			guard fadeSlot.owns(token) else { return }
			await applyVolume(effectiveVolume, on: target, generation: generation)
			finishFade(token)
		}
	}

	func stopAndClearPlayer() {
		let playerToStop = player
		sourceChangeSlot.invalidate()
		invalidatePlayerTasks()
		transition(.stopped)
		player = nil
		playbackState = nil
		currentSource = nil
		lastObservedTitle = nil
		lastObservedVideoID = nil
		currentMusicTitle = nil
		currentMusicVideoID = nil
		nowPlaying.clear()

		Task { [log = lifecycle.log, commands = playerCommands] in
			do {
				if let playerToStop { try await commands.pause(playerToStop) }
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
		levels: [Double],
		volume: @MainActor () -> Double,
		on player: YouTubePlayer,
		generation: TaskSlot.Token,
		stepInterval: Double,
		token: TaskSlot.Token
	) async -> Bool {
		for level in levels {
			guard fadeSlot.owns(token) else { return false }
			await applyVolume(volume() * level, on: player, generation: generation)
			do {
				try await sleep(for: .seconds(stepInterval))
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
