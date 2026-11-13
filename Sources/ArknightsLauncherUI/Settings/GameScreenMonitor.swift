// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import Observation

/// The connected displays. The list refreshes on each screen change, not on a timer.
@MainActor
@Observable
final class GameScreenMonitor {
	private(set) var list = GameScreenList.system()

	/// Refreshes the list until the caller's task is cancelled. A view's `.task` cancels it when
	/// the view disappears.
	func observe() async {
		let changes = NotificationCenter.default.notifications(
			named: NSApplication.didChangeScreenParametersNotification)
		for await _ in changes {
			list = GameScreenList.system()
		}
	}
}
