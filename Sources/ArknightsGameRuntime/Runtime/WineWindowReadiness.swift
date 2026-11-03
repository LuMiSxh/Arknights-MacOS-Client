// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import CoreGraphics
import Foundation

// Polls `CGWindowListCopyWindowInfo` for the game's onscreen window. Process launch alone is
// not enough: Wine's startup can succeed well before Arknights has a visible, sized window.
struct WineWindowReadiness {
	static func wait(
		processIdentifier: Int32,
		timeout: Duration = AppConstants.Timeouts.windowReadiness,
		pollInterval: Duration = AppConstants.Timeouts.windowPollInterval,
		clock: any Clock<Duration> = ContinuousClock()
	) async throws {
		try await poll(
			processIdentifier: processIdentifier, timeout: timeout, pollInterval: pollInterval,
			clock: clock)
	}

	private static func poll<C: Clock>(
		processIdentifier: Int32,
		timeout: Duration,
		pollInterval: Duration,
		clock: C
	) async throws where C.Duration == Duration {
		let deadline = clock.now.advanced(by: timeout)
		while !isVisible(processIdentifier: processIdentifier, windows: currentWindows())
			&& NSRunningApplication(processIdentifier: processIdentifier)?.activationPolicy
				!= .regular
		{
			guard clock.now < deadline else { throw GameRuntimeError.runtimeWindowTimeout }
			try await clock.sleep(for: pollInterval, tolerance: pollInterval / 10)
		}
	}

	static func isVisible(processIdentifier: Int32, windows: [[String: Any]]) -> Bool {
		GameWindowLocator.select(
			windows.compactMap(GameWindowCandidate.init(windowInfo:)), pid: processIdentifier)
			!= nil
	}

	private static func currentWindows() -> [[String: Any]] {
		CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
			as? [[String: Any]] ?? []
	}
}
