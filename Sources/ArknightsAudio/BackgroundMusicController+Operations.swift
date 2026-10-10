// SPDX-License-Identifier: MPL-2.0

import Foundation
import YouTubePlayerKit

extension BackgroundMusicController {
	func invalidatePlayerTasks() {
		playerGeneration = UUID()
		loadingTask?.cancel()
		controlTask?.cancel()
		shuffleTask?.cancel()
		fadeTask?.cancel()
		volumeTask?.cancel()
		loadingTask = nil
		controlTask = nil
		shuffleTask = nil
		fadeTask = nil
		volumeTask = nil
		operation = .idle
		playbackExpectation = nil
		fadeOperation = nil
	}

	func beginOperation(
		_ kind: BackgroundMusicOperationKind,
		on targetPlayer: YouTubePlayer
	) -> BackgroundMusicOperationToken {
		controlTask?.cancel()
		playbackExpectation = nil
		let token = BackgroundMusicOperationToken(
			generation: playerGeneration,
			player: targetPlayer
		)
		switch kind {
		case .trackChange:
			operation = .trackChange(token)
		case .playbackChange(let intent):
			operation = .playbackChange(token, intent)
		}
		return token
	}

	func finishOperation(_ token: BackgroundMusicOperationToken) {
		guard isCurrent(token) else { return }
		operation = .idle
	}

	@discardableResult
	func expectPlayback(
		_ intent: PlaybackIntent,
		on targetPlayer: YouTubePlayer
	) -> BackgroundMusicPlaybackExpectation {
		let expectation = BackgroundMusicPlaybackExpectation(
			generation: playerGeneration,
			player: targetPlayer,
			intent: intent
		)
		playbackExpectation = expectation
		nowPlaying.updatePlayback(isPlaying: intent == .playing)
		return expectation
	}

	func clearPlaybackExpectation(_ expectation: BackgroundMusicPlaybackExpectation) {
		guard playbackExpectation?.id == expectation.id else { return }
		playbackExpectation = nil
		nowPlaying.updatePlayback(isPlaying: isPlaying)
	}

	func beginFade(on targetPlayer: YouTubePlayer) -> BackgroundMusicFadeOperation {
		fadeTask?.cancel()
		let operation = BackgroundMusicFadeOperation(
			generation: playerGeneration,
			player: targetPlayer
		)
		fadeOperation = operation
		return operation
	}

	func cancelFade() {
		fadeTask?.cancel()
		fadeTask = nil
		fadeOperation = nil
	}

	func isCurrent(_ token: BackgroundMusicOperationToken) -> Bool {
		guard playerGeneration == token.generation, player === token.player else { return false }
		return operation.token?.id == token.id
	}

	func isCurrent(_ expectation: BackgroundMusicPlaybackExpectation) -> Bool {
		guard playbackExpectation?.id == expectation.id else { return false }
		return playerGeneration == expectation.generation
			&& player === expectation.player
	}

	func isCurrent(_ operation: BackgroundMusicFadeOperation) -> Bool {
		playerGeneration == operation.generation
			&& player === operation.player
			&& fadeOperation?.id == operation.id
	}

	func isCurrent(_ targetPlayer: YouTubePlayer, generation: UUID) -> Bool {
		playerGeneration == generation && player === targetPlayer
	}

	func scheduleVolumeUpdate(to volume: Double) {
		volumeTask?.cancel()
		guard let player else { return }
		let generation = playerGeneration
		volumeTask = Task { [weak self] in
			guard let self else { return }
			await applyVolume(volume, on: player, generation: generation)
			guard !Task.isCancelled, isCurrent(player, generation: generation) else { return }
			volumeTask = nil
		}
	}
}
