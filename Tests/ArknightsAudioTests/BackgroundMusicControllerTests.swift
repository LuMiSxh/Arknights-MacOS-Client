// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsCustomization
import ArknightsTestSupport
import Foundation
import Testing
import YouTubePlayerKit

@testable import ArknightsAudio

@MainActor
struct BackgroundMusicControllerTests {
	@Test
	func newerPlayIntentIgnoresALatePausedStateFromThePreviousRequest() throws {
		let temporary = try TemporaryDirectory("BackgroundMusicControllerTests")
		defer { temporary.remove() }
		let (defaults, suiteName) = makeIsolatedDefaults("BackgroundMusicControllerTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let controller = makeController(root: temporary.url, defaults: defaults)

		let player = YouTubePlayer(source: .video(id: "test"))
		controller.player = player
		let pauseOperation = controller.beginOperation(.playbackChange(.paused))
		controller.expectPlayback(.paused)
		controller.finishOperation(pauseOperation)

		let playOperation = controller.beginOperation(.playbackChange(.playing))
		controller.expectPlayback(.playing)
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

	private func makeController(root: URL, defaults: UserDefaults) -> BackgroundMusicController {
		let preferences = LauncherPreferencesStore(defaults: defaults)
		let paths = AppPaths(
			applicationSupportDirectory: root.appending(path: "Support"),
			cachesDirectory: root.appending(path: "Caches"),
			libraryDirectory: root.appending(path: "Library")
		)
		let lifecycle = LauncherLifecycleStore(
			log: LauncherLog(fileURL: paths.launcherLogFile)
		)
		let iconManager = LauncherIconManager(
			setBundleIcon: { _ in true },
			setRunningIcon: { _ in },
			defaultIcon: { NSImage(size: NSSize(width: 64, height: 64)) }
		)
		return BackgroundMusicController(
			lifecycle: lifecycle,
			settings: LauncherPreferencesController(store: preferences),
			launcherIconManager: iconManager,
			openURL: { _ in }
		)
	}
}
