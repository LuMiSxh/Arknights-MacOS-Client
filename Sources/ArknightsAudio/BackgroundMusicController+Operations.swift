// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import YouTubePlayerKit

extension BackgroundMusicController {
	func invalidatePlayerTasks() {
		playerGeneration = playerSlot.begin()
		loadingSlot.invalidate()
		operationTask?.cancel()
		operationTask = nil
		operationSlot.invalidate()
		cancelFade()
		volumeSlot.invalidate()
		operation = .idle
		discardPlaybackExpectation()
	}

	// The caller stores its task in `operationTask` so the next operation can cancel it.
	func beginOperation(_ kind: BackgroundMusicOperationKind) -> TaskSlot.Token {
		operationTask?.cancel()
		operationTask = nil
		discardPlaybackExpectation()
		let token = operationSlot.begin()
		switch kind {
		case .trackChange:
			operation = .trackChange(token)
		case .playbackChange(let intent):
			operation = .playbackChange(token, intent)
		}
		return token
	}

	func finishOperation(_ token: TaskSlot.Token) {
		guard isCurrent(token) else { return }
		operationSlot.invalidate()
		operation = .idle
	}

	@discardableResult
	func expectPlayback(_ intent: PlaybackIntent) -> BackgroundMusicPlaybackExpectation {
		let expectation = BackgroundMusicPlaybackExpectation(
			token: expectationSlot.begin(),
			intent: intent
		)
		playbackExpectation = expectation
		nowPlaying.updatePlayback(isPlaying: intent == .playing)
		return expectation
	}

	func clearPlaybackExpectation(_ expectation: BackgroundMusicPlaybackExpectation) {
		guard isCurrent(expectation) else { return }
		discardPlaybackExpectation()
		nowPlaying.updatePlayback(isPlaying: isPlaying)
	}

	func discardPlaybackExpectation() {
		expectationSlot.invalidate()
		playbackExpectation = nil
	}

	func cancelFade() {
		fadeSlot.invalidate()
		fadeTask = nil
	}

	func isCurrent(_ token: TaskSlot.Token) -> Bool {
		operationSlot.owns(token)
	}

	func isCurrent(_ expectation: BackgroundMusicPlaybackExpectation) -> Bool {
		expectationSlot.owns(expectation.token)
	}

	func isCurrent(_ targetPlayer: YouTubePlayer, generation: TaskSlot.Token) -> Bool {
		playerSlot.owns(generation) && player === targetPlayer
	}

	func scheduleVolumeUpdate(to volume: Double) {
		volumeSlot.invalidate()
		guard let player else { return }
		let generation = playerGeneration
		volumeSlot.replace { [weak self] token in
			guard let self else { return }
			await applyVolume(volume, on: player, generation: generation)
			guard volumeSlot.owns(token) else { return }
			volumeSlot.invalidate()
		}
	}
}
