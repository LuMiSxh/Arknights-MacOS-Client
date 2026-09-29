// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherGameLifecycleTests {
	@Test
	func stopIsEnabledWhilePreparingLaunchingAndRunning() {
		let sessionID = UUID()
		#expect(GameSessionController.canStopGame(for: .preparingGame(sessionID: sessionID)))
		#expect(
			GameSessionController.canStopGame(
				for: .launchingGame(sessionID: sessionID, processIdentifier: nil)
			))
		#expect(
			GameSessionController.canStopGame(
				for: .runningGame(sessionID: sessionID, processIdentifier: 42)
			))
		#expect(
			!GameSessionController.canStopGame(
				for: .stoppingGame(sessionID: sessionID, processIdentifier: nil)
			))
		#expect(!GameSessionController.canStopGame(for: .idle))
	}

	@Test
	func stoppingBeforeTheGameSpawnsCancelsTheLaunchAndKeepsPrefixOwnership() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		let sessionID = UUID()
		let launch = Task<Void, Never> {
			while !Task.isCancelled { await Task.yield() }
		}
		model.lifecycle.activity = .preparingGame(sessionID: sessionID)
		model.gameSession.launchTask = launch

		model.gameSession.stopGame()
		await launch.value

		#expect(
			model.lifecycle.activity
				== .stoppingGame(sessionID: sessionID, processIdentifier: nil)
		)
		#expect(model.lifecycle.activityMessage == LauncherStatus.stoppingGame.message)
		#expect(!model.lifecycle.canBeginExclusiveActivity)
		#expect(!model.lifecycle.activity.isGameProcessRunning)
		await api.resolveBranding()
	}

	@Test
	func directWineProcessExitTracksStartupAndRunningSessions() {
		let sessionID = UUID()
		#expect(
			GameSessionController.directWineProcessExitAction(
				activity: .launchingGame(sessionID: sessionID, processIdentifier: nil),
				sessionID: sessionID
			) == .startupFailure)
		#expect(
			GameSessionController.directWineProcessExitAction(
				activity: .launchingGame(sessionID: sessionID, processIdentifier: 42),
				sessionID: sessionID
			) == .startupFailure)
		#expect(
			GameSessionController.directWineProcessExitAction(
				activity: .runningGame(sessionID: sessionID, processIdentifier: 42),
				sessionID: sessionID
			) == .gameExited)
		#expect(
			GameSessionController.directWineProcessExitAction(
				activity: .launchingGame(sessionID: UUID(), processIdentifier: nil),
				sessionID: sessionID
			) == .ignore)
	}

	@Test
	func terminalLifecycleRecordsAVisibleSessionExactlyOnce() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		let sessionID = UUID()
		model.lifecycle.activity = .runningGame(
			sessionID: sessionID,
			processIdentifier: 42
		)
		model.playtimeStatistics.start(sessionID: sessionID, region: .japan)

		model.gameSession.finishGameSession(sessionID)
		let recordedTotal = model.playtimeStatistics.totalDuration
		model.gameSession.finishGameSession(sessionID)

		#expect(model.playtimeStatistics.statistics.latestSession?.region == .japan)
		#expect(model.playtimeStatistics.totalDuration == recordedTotal)
		#expect(model.playtimeStatistics.statistics.activeSession == nil)
		await api.resolveBranding()
	}

	@Test(arguments: ExitDiagnosticsScenario.allCases)
	func exitDiagnosticsIncludeOnlyAvailableCrashDetails(scenario: ExitDiagnosticsScenario) throws {
		let fileManager = FileManager.default
		var logURL: URL?
		defer {
			if let logURL {
				try? fileManager.removeItem(at: logURL)
			}
		}
		let exit: WineProcessExit
		let since: Date?
		switch scenario {
		case .normalExitWithoutLog:
			exit = WineProcessExit(status: 0, reason: .exit)
			since = nil
		case .crashWithRuntimeLog:
			let url = fileManager.temporaryDirectory.appendingPathComponent(
				"test-\(UUID().uuidString).log"
			)
			logURL = url
			try "err: something exploded".write(
				to: url, atomically: true, encoding: .utf8)
			exit = WineProcessExit(status: 134, reason: .uncaughtSignal)
			since = Date(timeIntervalSinceNow: -90)
		}

		let summary = GameSessionController.exitDiagnostics(exit, since: since, logURL: logURL)
		switch scenario {
		case .normalExitWithoutLog:
			#expect(summary == "status=0 reason=exit")
		case .crashWithRuntimeLog:
			let logURL = try #require(logURL)
			#expect(summary.contains("status=134 reason=uncaughtSignal"))
			#expect(summary.contains("ranFor="))
			#expect(
				summary.contains("\(logURL.lastPathComponent) tail: err: something exploded")
			)
		}
	}

	@Test
	func recentCrashReportPathFindsOnlyArknightsReportsWithinTheTimeWindow() throws {
		let fileManager = FileManager.default
		let directory = fileManager.temporaryDirectory.appending(
			path: "crash-reports-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
		defer { try? fileManager.removeItem(at: directory) }
		let matching = directory.appending(path: "Arknights-2026-08-16-1234.ips")
		let unrelated = directory.appending(path: "Safari-2026-08-16-1234.ips")
		try Data().write(to: matching)
		try Data().write(to: unrelated)
		let crashDate = Date()

		#expect(
			GameSessionController.recentCrashReportPath(
				near: crashDate,
				in: directory,
				window: 120,
				fileManager: fileManager
			)?.hasSuffix(matching.lastPathComponent) == true
		)
		#expect(
			GameSessionController.recentCrashReportPath(
				near: crashDate.addingTimeInterval(600),
				in: directory,
				window: 120,
				fileManager: fileManager
			) == nil
		)
	}
}

enum ExitDiagnosticsScenario: String, CaseIterable, Sendable {
	case normalExitWithoutLog
	case crashWithRuntimeLog
}
