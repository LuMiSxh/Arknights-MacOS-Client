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
		let (controller, _, defaults, suiteName, _) = makeController(openURL: { openedURL = $0 })
		defer { defaults.removePersistentDomain(forName: suiteName) }

		controller.currentMusicVideoID = "video-id"
		controller.openCurrentMusicURL()

		#expect(openedURL?.absoluteString == "https://www.youtube.com/watch?v=video-id")
	}

	@Test
	func playbackIntentImmediatelyDrivesControlsUntilPlayerConfirmsIt() {
		let (controller, _, defaults, suiteName, _) = makeController()
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
		let (controller, _, defaults, suiteName, _) = makeController()
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
		let (controller, _, defaults, suiteName, _) = makeController()
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
		let (controller, settings, defaults, suiteName, _) = makeController()
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

	@Test
	func sourceChangesWaitForEditingToSettleBeforeReloading() async {
		let (controller, settings, defaults, suiteName, _) = makeController()
		defer { defaults.removePersistentDomain(forName: suiteName) }

		settings.playsLauncherMusic = true
		settings.launcherMusicURL = "https://www.youtube.com/watch?v=first"
		controller.enabledDidChange(to: true)
		#expect(controller.currentSource == .video(id: "first"))

		settings.launcherMusicURL = "https://www.youtube.com/watch?v=second"
		controller.sourceDidChange()
		#expect(controller.currentSource == .video(id: "first"))

		#expect(
			await waitForCondition {
				controller.currentSource == .video(id: "second")
			}
		)
	}

	@Test
	func interruptedPlayFailureReenablesControlsAndPreservesNewerRequest() async throws {
		let commands = SuspendedMusicPlayerCommands()
		let playerCommands = BackgroundMusicPlayerCommands(
			play: { try await commands.play($0) },
			pause: { try await commands.pause($0) },
			setVolume: { try await commands.setVolume($0, $1) }
		)
		let (controller, _, defaults, suiteName, _) = makeController(
			playerCommands: playerCommands
		)
		defer {
			controller.cancelFade()
			commands.completePlay(1)
			commands.completePlay(3)
			defaults.removePersistentDomain(forName: suiteName)
		}

		let player = YouTubePlayer(source: .video(id: "test"))
		controller.player = player
		controller.playbackState = .paused
		controller.togglePlayback()
		let originalOperation = try #require(controller.operation.token)
		let originalFade = try #require(controller.fadeTask)
		await commands.waitForPlay(1)
		#expect(controller.isManuallyPaused == false)
		#expect(controller.isChangingPlayback)

		controller.lifecycle.activity = .runningGame(
			sessionID: UUID(),
			processIdentifier: 42
		)
		controller.gameRunningDidChange(to: true)
		let gamePauseFade = try #require(controller.fadeTask)
		await gamePauseFade.value
		#expect(commands.pauseCount == 1)
		#expect(!controller.isCurrent(originalOperation))
		controller.playbackState = .playing
		controller.reconcilePlaybackIntent(with: .playing)
		#expect(controller.playbackIntent == .paused)
		controller.playbackState = .paused
		controller.reconcilePlaybackIntent(with: .paused)
		#expect(controller.playbackIntent == nil)

		#expect(!controller.isChangingPlayback)

		controller.lifecycle.activity = .idle
		controller.gameRunningDidChange(to: false)
		let resumeExpectation = try #require(controller.playbackExpectation)
		#expect(resumeExpectation.intent == .playing)
		let resumeFade = try #require(controller.fadeTask)
		await commands.waitForPlay(2)
		await resumeFade.value
		#expect(controller.playbackIntent == nil)
		#expect(!controller.isManuallyPaused)
		#expect(!controller.isChangingPlayback)
		#expect(!controller.controlsAreDisabled)

		controller.togglePlayback()
		let newerOperation = try #require(controller.operation.token)
		let newerFade = try #require(controller.fadeTask)
		await commands.waitForPlay(3)
		commands.completePlay(1)
		await originalFade.value
		#expect(controller.isCurrent(newerOperation))
		#expect(controller.isChangingPlayback)
		#expect(controller.player === player)

		controller.playbackState = .playing
		controller.reconcilePlaybackIntent(with: .playing)
		#expect(!controller.isChangingPlayback)
		#expect(!controller.controlsAreDisabled)
		controller.cancelFade()
		commands.completePlay(3)
		await newerFade.value
	}

	@Test
	func audioDiagnosticsOmitInvalidURLsAndPlaylistIDs() async throws {
		let (controller, settings, defaults, suiteName, logFileURL) = makeController()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let invalidURL = "invalid-url?token=INVALID_URL_SENTINEL"
		let playlistID = "PRIVATE_PLAYLIST_SENTINEL"

		settings.launcherMusicURL = invalidURL
		controller.enabledDidChange(to: true)
		settings.launcherMusicURL = "https://www.youtube.com/playlist?list=\(playlistID)"
		controller.enabledDidChange(to: true)
		await controller.lifecycle.log.flush()

		let content = try String(contentsOf: logFileURL, encoding: .utf8)
		#expect(!content.contains(invalidURL))
		#expect(!content.contains(playlistID))
		#expect(content.contains("[ERROR] Background music failed: invalid YouTube URL"))
		#expect(
			content.contains(
				"[INFO] Background music initializing player with source type: playlist")
		)
	}

	private func makeController(
		openURL: @escaping (URL) -> Void = { _ in },
		playerCommands: BackgroundMusicPlayerCommands = .live
	) -> (
		BackgroundMusicController, LauncherPreferencesController, UserDefaults, String, URL
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
				playerCommands: playerCommands,
				openURL: openURL
			),
			settings,
			defaults,
			identifier,
			paths.launcherLogFile
		)
	}
}

@MainActor
private final class SuspendedMusicPlayerCommands {
	enum Failure: Error {
		case automaticResume
	}

	private(set) var pauseCount = 0
	private var playCount = 0
	private var pendingPlays: [Int: CheckedContinuation<Void, any Error>] = [:]
	private var playWaiters: [Int: CheckedContinuation<Void, Never>] = [:]

	func play(_ player: YouTubePlayer) async throws {
		playCount += 1
		let request = playCount
		playWaiters.removeValue(forKey: request)?.resume()
		if request == 2 { throw Failure.automaticResume }
		try await withCheckedThrowingContinuation { continuation in
			pendingPlays[request] = continuation
		}
	}

	func pause(_ player: YouTubePlayer) async throws {
		pauseCount += 1
	}

	func setVolume(_ player: YouTubePlayer, _ volume: Int) async throws {}

	func waitForPlay(_ request: Int) async {
		guard playCount < request else { return }
		await withCheckedContinuation { continuation in
			playWaiters[request] = continuation
		}
	}

	func completePlay(_ request: Int) {
		pendingPlays.removeValue(forKey: request)?.resume(returning: ())
	}
}
