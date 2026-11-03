// SPDX-License-Identifier: MPL-2.0

import ArknightsInfrastructure
import CoreGraphics

/// Reads and requests the Screen Recording permission. Tests replace it.
struct ScreenCapturePermission: Sendable {
	/// Does not prompt.
	var isGranted: @Sendable () -> Bool
	/// Shows the system prompt the first time. Later calls do nothing visible.
	var request: @Sendable () -> Void

	static let system = ScreenCapturePermission(
		isGranted: { CGPreflightScreenCaptureAccess() },
		request: { _ = CGRequestScreenCaptureAccess() })
}

/// A registered global shortcut. Tests replace the real one.
protocol HotKeyRegistration {
	func cancel()
}

extension GlobalHotKey: HotKeyRegistration {}
