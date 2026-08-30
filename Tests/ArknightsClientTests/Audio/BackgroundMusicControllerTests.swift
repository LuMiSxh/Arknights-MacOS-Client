// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import Testing
import YouTubePlayerKit

@testable import ArknightsClient

@MainActor
struct BackgroundMusicControllerTests {
	@Test
	func opensCurrentMusicURLThroughTheInjectedOpener() {
		var openedURL: URL?
		let (controller, _, defaults, suiteName) = makeController(openURL: { openedURL = $0 })
		defer { defaults.removePersistentDomain(forName: suiteName) }

		controller.currentMusicVideoID = "video-id"
		controller.openCurrentMusicURL()

		#expect(openedURL?.absoluteString == "https://www.youtube.com/watch?v=video-id")
	}

	@Test
	func playbackIntentImmediatelyDrivesControlsUntilPlayerConfirmsIt() {
		let (controller, _, defaults, suiteName) = makeController()
		defer { defaults.removePersistentDomain(forName: suiteName) }

		controller.playbackState = .playing
		let player = YouTubePlayer(source: .video(id: "test"))
		controller.player = player
		_ = controller.beginOperation(.playbackChange(.paused), on: player)
		controller.expectPlayback(.paused, on: player)
		#expect(!controller.isPlaying)
		#expect(controller.controlsAreDisabled)

		controller.playbackState = .paused
		controller.reconcilePlaybackIntent(with: .paused)
		#expect(controller.playbackIntent == nil)
		#expect(!controller.isChangingPlayback)
		#expect(!controller.isPlaying)
	}

	@Test
	func newerPlayIntentIgnoresALatePausedStateFromThePreviousRequest() {
		let (controller, _, defaults, suiteName) = makeController()
		defer { defaults.removePersistentDomain(forName: suiteName) }

		let player = YouTubePlayer(source: .video(id: "test"))
		controller.player = player
		let pauseOperation = controller.beginOperation(.playbackChange(.paused), on: player)
		controller.expectPlayback(.paused, on: player)
		controller.finishOperation(pauseOperation)

		let playOperation = controller.beginOperation(.playbackChange(.playing), on: player)
		controller.expectPlayback(.playing, on: player)
		controller.finishOperation(playOperation)
		controller.playbackState = .paused
		controller.reconcilePlaybackIntent(with: .paused)

		#expect(controller.playbackIntent == .playing)
		#expect(controller.isPlaying)

		controller.playbackState = .buffering
		controller.reconcilePlaybackIntent(with: .buffering)
		#expect(controller.playbackIntent == nil)
		#expect(controller.isPlaying)
	}

	@Test
	func repeatedTitleStillUpdatesTheCurrentVideoIdentifier() {
		let (controller, _, defaults, suiteName) = makeController()
		defer { defaults.removePersistentDomain(forName: suiteName) }

		#expect(
			controller.applyTrackTitle(
				from: .init(title: "Chase the Light", videoId: "first")
			)
		)
		#expect(
			controller.applyTrackTitle(
				from: .init(title: "Chase the Light", videoId: "second")
			)
		)

		#expect(controller.currentMusicTitle == "Chase the Light")
		#expect(controller.currentMusicVideoID == "second")
		#expect(controller.lastObservedVideoID == "second")
	}

	@Test
	func mutePreservesTheConfiguredVolumeAndRestoresIt() {
		let (controller, settings, defaults, suiteName) = makeController()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		settings.launcherMusicVolume = 0.7

		controller.toggleMute()

		#expect(controller.isMuted)
		#expect(controller.effectiveVolume == 0)
		#expect(settings.launcherMusicVolume == 0.7)

		controller.toggleMute()

		#expect(!controller.isMuted)
		#expect(controller.effectiveVolume == 0.7)
	}

	private func makeController(openURL: @escaping (URL) -> Void = { _ in }) -> (
		BackgroundMusicController, LauncherPreferencesController, UserDefaults, String
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
		let paths = AppPaths(
			applicationSupportDirectory: root.appending(path: "Support"),
			cachesDirectory: root.appending(path: "Caches"),
			libraryDirectory: root.appending(path: "Library")
		)
		let lifecycle = LauncherLifecycleStore(
			log: LauncherLog(fileURL: paths.launcherLogFile)
		)
		let settings = LauncherPreferencesController(store: preferences)
		let iconManager = LauncherIconManager(
			setBundleIcon: { _ in true },
			setRunningIcon: { _ in },
			defaultIcon: { NSImage(size: NSSize(width: 64, height: 64)) }
		)
		return (
			BackgroundMusicController(
				lifecycle: lifecycle,
				settings: settings,
				launcherIconManager: iconManager,
				openURL: openURL
			),
			settings,
			defaults,
			identifier
		)
	}
}
