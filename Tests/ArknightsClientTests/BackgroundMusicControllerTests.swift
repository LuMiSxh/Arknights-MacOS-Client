// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing
import YouTubePlayerKit

@testable import ArknightsClient

@MainActor
struct BackgroundMusicControllerTests {
	@Test
	func trackNavigationIsAvailableOnlyForPlaylists() {
		let (controller, defaults, suiteName) = makeController()
		defer { defaults.removePersistentDomain(forName: suiteName) }

		controller.currentSource = .video(id: "one")
		#expect(!controller.canNavigatePlaylist)

		controller.currentSource = .playlist(id: "many")
		#expect(controller.canNavigatePlaylist)
	}

	@Test
	func bufferingCountsAsActivePlaybackForThePauseControl() {
		let (controller, defaults, suiteName) = makeController()
		defer { defaults.removePersistentDomain(forName: suiteName) }

		controller.playbackState = .paused
		#expect(!controller.isPlaying)

		controller.playbackState = .buffering
		#expect(controller.isPlaying)

		controller.playbackState = .playing
		#expect(controller.isPlaying)
	}

	@Test
	func playbackIntentImmediatelyDrivesControlsUntilPlayerConfirmsIt() {
		let (controller, defaults, suiteName) = makeController()
		defer { defaults.removePersistentDomain(forName: suiteName) }

		controller.playbackState = .playing
		controller.playbackIntent = .paused
		controller.isChangingPlayback = true
		#expect(!controller.isPlaying)
		#expect(controller.controlsAreDisabled)

		controller.playbackState = .paused
		controller.reconcilePlaybackIntent(with: .paused)
		#expect(controller.playbackIntent == nil)
		#expect(!controller.isChangingPlayback)
		#expect(!controller.isPlaying)
	}

	private func makeController() -> (
		BackgroundMusicController, UserDefaults, String
	) {
		let identifier = "BackgroundMusicControllerTests.\(UUID().uuidString)"
		let root = URL(filePath: NSTemporaryDirectory()).appending(
			path: identifier,
			directoryHint: .isDirectory
		)
		let defaults = UserDefaults(suiteName: identifier)!
		let preferences = LauncherPreferencesStore(defaults: defaults)
		preferences.setAutomaticGameUpdates(false)
		preferences.setAutomaticLauncherUpdates(false)
		preferences.setAnnouncementsEnabled(false)
		let model = LauncherViewModel(
			paths: AppPaths(
				applicationSupportDirectory: root.appending(path: "Support"),
				cachesDirectory: root.appending(path: "Caches"),
				libraryDirectory: root.appending(path: "Library")
			),
			preferences: preferences,
			arguments: ["--developer-scenario", "ready"]
		)
		return (BackgroundMusicController(model: model), defaults, identifier)
	}
}
