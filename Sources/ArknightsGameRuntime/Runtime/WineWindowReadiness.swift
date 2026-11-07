// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import CoreGraphics
import Darwin
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
		isVisible(
			processIdentifier: processIdentifier,
			windows: windows,
			descendantIdentifiers: descendants(of: processIdentifier)
		)
	}

	/// Wine's launcher process (`start.exe`) owns the child that creates the game window, so a
	/// window of a descendant is the game window too.
	static func isVisible(
		processIdentifier: Int32,
		windows: [[String: Any]],
		descendantIdentifiers: [Int32]
	) -> Bool {
		let candidates = windows.compactMap(GameWindowCandidate.init(windowInfo:))
		if GameWindowLocator.select(candidates, pid: processIdentifier) != nil {
			return true
		}
		return descendantIdentifiers.contains {
			GameWindowLocator.select(candidates, pid: $0) != nil
		}
	}

	private static func descendants(of processIdentifier: Int32) -> [Int32] {
		var descendants: [Int32] = []
		var visited: Set<Int32> = [processIdentifier]
		var pending: [Int32] = [processIdentifier]
		while let parent = pending.popLast() {
			for child in children(of: parent) where visited.insert(child).inserted {
				descendants.append(child)
				pending.append(child)
			}
		}
		return descendants
	}

	// `proc_listchildpids` visits only the process tree. The full `KERN_PROC_ALL` table costs more
	// and this runs once per readiness poll.
	private static func children(of processIdentifier: Int32) -> [Int32] {
		let capacity = 256
		var buffer = [pid_t](repeating: 0, count: capacity)
		let listed = proc_listchildpids(
			processIdentifier, &buffer, Int32(capacity * MemoryLayout<pid_t>.size))
		return childIdentifiers(listed: Int(listed), buffer: buffer, capacity: capacity)
	}

	// `proc_listchildpids` returns the number of PIDs written, not the byte count, so the caller
	// must not divide by `MemoryLayout<pid_t>.size`.
	static func childIdentifiers(listed: Int, buffer: [pid_t], capacity: Int) -> [Int32] {
		guard listed > 0 else { return [] }
		return buffer[0..<min(capacity, listed)].map { Int32($0) }
	}

	private static func currentWindows() -> [[String: Any]] {
		CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
			as? [[String: Any]] ?? []
	}
}
