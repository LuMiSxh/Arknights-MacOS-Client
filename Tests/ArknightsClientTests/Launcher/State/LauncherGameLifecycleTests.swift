// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherGameLifecycleTests {
	@Test
	func stopIsEnabledOnlyForRunningGameActivity() {
		let sessionID = UUID()
		#expect(
			!LauncherViewModel.canStopGame(
				for: .launchingGame(sessionID: sessionID, processIdentifier: nil)
			))
		#expect(
			LauncherViewModel.canStopGame(
				for: .runningGame(sessionID: sessionID, processIdentifier: 42)
			))
		#expect(
			!LauncherViewModel.canStopGame(
				for: .stoppingGame(sessionID: sessionID, processIdentifier: 42)
			))
		#expect(!LauncherViewModel.canStopGame(for: .idle))
	}

	@Test
	func directWineProcessExitTracksStartupAndRunningSessions() {
		let sessionID = UUID()
		#expect(
			LauncherViewModel.directWineProcessExitAction(
				activity: .launchingGame(sessionID: sessionID, processIdentifier: nil),
				sessionID: sessionID
			) == .startupFailure)
		#expect(
			LauncherViewModel.directWineProcessExitAction(
				activity: .launchingGame(sessionID: sessionID, processIdentifier: 42),
				sessionID: sessionID
			) == .startupFailure)
		#expect(
			LauncherViewModel.directWineProcessExitAction(
				activity: .runningGame(sessionID: sessionID, processIdentifier: 42),
				sessionID: sessionID
			) == .gameExited)
		#expect(
			LauncherViewModel.directWineProcessExitAction(
				activity: .launchingGame(sessionID: UUID(), processIdentifier: nil),
				sessionID: sessionID
			) == .ignore)
	}

	@Test
	func exitDiagnosticsOmitsCrashDetailsWhenNoLogIsAvailable() {
		let summary = LauncherViewModel.exitDiagnostics(
			WineProcessExit(status: 0, reason: .exit),
			since: nil,
			logURL: nil
		)

		#expect(summary == "status=0 reason=exit")
	}

	@Test
	func exitDiagnosticsIncludesDurationAndWineLogTailForACrash() throws {
		let fileManager = FileManager.default
		let logURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? fileManager.removeItem(at: logURL) }
		try "err: something exploded".write(to: logURL, atomically: true, encoding: .utf8)

		let summary = LauncherViewModel.exitDiagnostics(
			WineProcessExit(status: 134, reason: .uncaughtSignal),
			since: Date(timeIntervalSinceNow: -90),
			logURL: logURL
		)

		#expect(summary.contains("status=134 reason=uncaughtSignal"))
		#expect(summary.contains("ranFor="))
		#expect(summary.contains("wine.log tail: err: something exploded"))
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
			LauncherViewModel.recentCrashReportPath(
				near: crashDate,
				in: directory,
				window: 120,
				fileManager: fileManager
			)?.hasSuffix(matching.lastPathComponent) == true
		)
		#expect(
			LauncherViewModel.recentCrashReportPath(
				near: crashDate.addingTimeInterval(600),
				in: directory,
				window: 120,
				fileManager: fileManager
			) == nil
		)
	}
}
