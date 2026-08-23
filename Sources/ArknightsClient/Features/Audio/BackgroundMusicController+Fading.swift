// SPDX-License-Identifier: MPL-2.0

import Foundation
import YouTubePlayerKit

extension BackgroundMusicController {
	func performFadeOut() {
		guard let player else { return }
		expectPlayback(.paused, on: player)
		volumeTask?.cancel()
		volumeTask = nil
		let operation = beginFade(on: player)
		fadeTask = Task { [weak self] in
			guard let self else { return }
			let startVolume = effectiveVolume
			let steps = AppConstants.Music.fadeSteps
			let stepInterval = AppConstants.Music.fadeOutDuration / Double(steps)

			for step in stride(from: steps, through: 0, by: -1) {
				guard !Task.isCancelled, isCurrent(operation) else { return }
				await applyVolume(
					startVolume * Double(step) / Double(steps),
					on: player,
					generation: operation.generation
				)
				do {
					try await Task.sleep(for: .seconds(stepInterval))
				} catch {
					return
				}
			}

			do {
				guard !Task.isCancelled, isCurrent(operation) else { return }
				try await player.pause()
				guard !Task.isCancelled, isCurrent(operation) else { return }
				await context.log.info("Background music faded out and paused")
			} catch {
				guard !Task.isCancelled, isCurrent(operation) else { return }
				await context.log.error(
					"Background music failed to pause after fading out: \(error.localizedDescription)"
				)
			}
			finishFade(operation)
		}
	}

	func performFadeIn(
		on targetPlayer: YouTubePlayer? = nil,
		userPlaybackOperation: BackgroundMusicOperationToken? = nil
	) {
		volumeTask?.cancel()
		volumeTask = nil
		guard let target = targetPlayer ?? player else { return }
		let expectation = expectPlayback(.playing, on: target)
		let operation = beginFade(on: target)
		fadeTask = Task { [weak self] in
			guard let self else { return }

			let targetVolume = effectiveVolume
			let steps = AppConstants.Music.fadeSteps
			let stepInterval = AppConstants.Music.fadeInDuration / Double(steps)

			guard isCurrent(operation) else { return }
			await applyVolume(0, on: target, generation: operation.generation)
			do {
				guard !Task.isCancelled, isCurrent(operation) else { return }
				try await target.play()
				guard !Task.isCancelled, isCurrent(operation) else { return }
				if let userPlaybackOperation {
					finishOperation(userPlaybackOperation)
				}
				await context.log.info("Background music resuming with fade-in")
				shuffleInitialPlaylistIfNeeded(on: target)
			} catch {
				guard !Task.isCancelled, isCurrent(operation) else { return }
				if let userPlaybackOperation {
					finishOperation(userPlaybackOperation)
				}
				clearPlaybackExpectation(expectation)
				await context.log.error(
					"Background music failed to resume: \(error.localizedDescription)"
				)
				finishFade(operation)
				return
			}

			for step in 1...steps {
				guard !Task.isCancelled, isCurrent(operation) else { return }
				await applyVolume(
					targetVolume * Double(step) / Double(steps),
					on: target,
					generation: operation.generation
				)
				do {
					try await Task.sleep(for: .seconds(stepInterval))
				} catch {
					return
				}
			}

			guard !Task.isCancelled, isCurrent(operation) else { return }
			await applyVolume(targetVolume, on: target, generation: operation.generation)
			finishFade(operation)
		}
	}

	func stopAndClearPlayer() {
		let playerToStop = player
		invalidatePlayerTasks()
		cancellables.removeAll()
		player = nil
		playbackState = nil
		currentSource = nil
		operation = .idle
		playbackExpectation = nil
		lastObservedTitle = nil
		lastObservedVideoID = nil
		context.currentMusicTitle = nil
		context.currentMusicVideoID = nil
		nowPlaying.clear()

		Task { [log = context.log] in
			do {
				try await playerToStop?.pause()
				await log.info("Background music stopped")
			} catch {
				await log.error(
					"Background music failed to stop cleanly: \(error.localizedDescription)"
				)
			}
		}
	}

	func applyVolume(_ volume: Double, on playerToUse: YouTubePlayer, generation: UUID) async {
		guard isCurrent(playerToUse, generation: generation) else { return }
		let normalizedVolume = max(0, min(100, Int(volume * 100)))
		do {
			try await playerToUse.evaluate(
				javaScript: .youTubePlayer(
					functionName: "setVolume",
					parameters: [normalizedVolume]
				)
			)
		} catch {
			guard !Task.isCancelled, isCurrent(playerToUse, generation: generation) else { return }
			await context.log.debug(
				"Background music volume update was not applied: \(error.localizedDescription)"
			)
		}
	}

	func finishFade(_ operation: BackgroundMusicFadeOperation) {
		guard isCurrent(operation) else { return }
		fadeOperation = nil
		fadeTask = nil
	}
}
