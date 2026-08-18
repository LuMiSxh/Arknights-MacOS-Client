// SPDX-License-Identifier: MPL-2.0

import AppKit
import CoreGraphics
import Foundation

/// Polls `CGWindowListCopyWindowInfo` for the game's onscreen window instead of trusting
/// process launch alone, since Wine's own startup can succeed well before Arknights actually
/// has a visible, appropriately sized window.
struct WineWindowReadiness {
	static func wait(
		processIdentifier: Int32,
		timeout: Duration = AppConstants.Timeouts.windowReadiness,
		pollInterval: Duration = AppConstants.Timeouts.windowPollInterval
	) async throws {
		let clock = ContinuousClock()
		let deadline = clock.now.advanced(by: timeout)
		while !isVisible(processIdentifier: processIdentifier, windows: currentWindows())
			&& NSRunningApplication(processIdentifier: processIdentifier)?.activationPolicy
				!= .regular
		{
			guard clock.now < deadline else { throw LauncherError.runtimeWindowTimeout }
			try await Task.sleep(for: pollInterval)
		}
	}

	static func isVisible(processIdentifier: Int32, windows: [[String: Any]]) -> Bool {
		windows.contains { window in
			guard
				(window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
					== processIdentifier,
				(window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
				(window[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue == true,
				(window[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 0 > 0,
				let bounds = window[kCGWindowBounds as String] as? [String: Any],
				(bounds["Width"] as? NSNumber)?.doubleValue ?? 0 >= 320,
				(bounds["Height"] as? NSNumber)?.doubleValue ?? 0 >= 200
			else {
				return false
			}
			return true
		}
	}

	private static func currentWindows() -> [[String: Any]] {
		CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
			as? [[String: Any]] ?? []
	}
}
