// SPDX-License-Identifier: MPL-2.0

import Foundation
import YouTubePlayerKit

extension BackgroundMusicController {
	func performFadeOut() {
		fadeTask?.cancel()
		volumeTask?.cancel()
		volumeTask = nil
		let fadeID = UUID()
		activeFadeID = fadeID
		fadeTask = Task { [weak self] in
			guard let self else { return }
			let startVolume = model.launcherMusicVolume
			let steps = AppConstants.Music.fadeSteps
			let stepInterval = AppConstants.Music.fadeOutDuration / Double(steps)

			for step in stride(from: steps, through: 0, by: -1) {
				guard !Task.isCancelled else { return }
				await applyVolume(startVolume * Double(step) / Double(steps))
				try? await Task.sleep(for: .seconds(stepInterval))
			}

			do {
				try await player?.pause()
				await model.log.info("Background music faded out and paused")
			} catch {
				await model.log.error(
					"Background music failed to pause after fading out: \(error.localizedDescription)"
				)
			}
			finishFade(id: fadeID)
		}
	}

	func performFadeIn(
		on targetPlayer: YouTubePlayer? = nil,
		isUserInitiated: Bool = false
	) {
		fadeTask?.cancel()
		volumeTask?.cancel()
		volumeTask = nil
		let fadeID = UUID()
		activeFadeID = fadeID
		fadeTask = Task { [weak self] in
			guard let self else { return }
			let target = targetPlayer ?? player
			guard let target else {
				finishFade(id: fadeID)
				return
			}

			let targetVolume = model.launcherMusicVolume
			let steps = AppConstants.Music.fadeSteps
			let stepInterval = AppConstants.Music.fadeInDuration / Double(steps)

			await applyVolume(0, on: target)
			do {
				try await target.play()
				if isUserInitiated { isChangingPlayback = false }
				await model.log.info("Background music resuming with fade-in")
			} catch {
				guard !Task.isCancelled else { return }
				if isUserInitiated {
					playbackIntent = nil
					isChangingPlayback = false
				}
				await model.log.error(
					"Background music failed to resume: \(error.localizedDescription)"
				)
				finishFade(id: fadeID)
				return
			}

			for step in 1...steps {
				guard !Task.isCancelled else { return }
				await applyVolume(
					targetVolume * Double(step) / Double(steps),
					on: target
				)
				try? await Task.sleep(for: .seconds(stepInterval))
			}

			await applyVolume(targetVolume, on: target)
			finishFade(id: fadeID)
		}
	}

	func stopAndClearPlayer() {
		let playerToStop = player
		loadingTask?.cancel()
		controlTask?.cancel()
		fadeTask?.cancel()
		shuffleTask?.cancel()
		volumeTask?.cancel()
		loadingTask = nil
		controlTask = nil
		fadeTask = nil
		shuffleTask = nil
		volumeTask = nil
		activeControlID = nil
		activeFadeID = nil
		cancellables.removeAll()
		player = nil
		playbackState = nil
		currentSource = nil
		isChangingTrack = false
		isChangingPlayback = false
		playbackIntent = nil
		lastObservedTitle = nil
		model.currentMusicTitle = nil
		model.currentMusicVideoID = nil

		Task { [log = model.log] in
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

	func applyVolume(_ volume: Double, on targetPlayer: YouTubePlayer? = nil) async {
		guard let playerToUse = targetPlayer ?? player else { return }
		let normalizedVolume = max(0, min(100, Int(volume * 100)))
		do {
			try await playerToUse.evaluate(
				javaScript: .youTubePlayer(
					functionName: "setVolume",
					parameters: [normalizedVolume]
				)
			)
		} catch {
			guard !Task.isCancelled else { return }
			await model.log.debug(
				"Background music volume update was not applied: \(error.localizedDescription)"
			)
		}
	}

	private func finishFade(id: UUID) {
		guard activeFadeID == id else { return }
		activeFadeID = nil
		fadeTask = nil
	}
}
