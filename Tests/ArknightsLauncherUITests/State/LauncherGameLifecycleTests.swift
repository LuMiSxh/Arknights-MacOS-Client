// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Testing

@testable import ArknightsGameRuntime
@testable import ArknightsLauncherUI

@MainActor
struct LauncherGameLifecycleTests {
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
}
