// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation
import Synchronization

/// Startup instrumentation. Logs each launch milestone once at debug level, measured from the
/// kernel's process start time, so a start can be checked against the one-second goal.
///
/// Milestones are buffered until `attach(_:enabled:)` and dropped when debug logging is off.
/// Read them with `grep 'Startup:' ~/Library/Logs/com.lumisxh.arknights-client/launcher.log`.
package final class StartupTimeline: Sendable {
	private enum Sink {
		case pending([String])
		case log(LauncherLog)
		case disabled
	}

	private struct State {
		var sink = Sink.pending([])
		var loggedMessages: Set<String> = []
	}

	package static let shared = StartupTimeline()

	private let state = Mutex(State())
	private let startedAt: Date

	private init() {
		startedAt = Self.processStartDate() ?? Date()
	}

	/// Connects the shared timeline to the launcher log and flushes anything recorded earlier.
	/// When `enabled` is false, earlier milestones are dropped and later ones are ignored.
	package func attach(_ log: LauncherLog, enabled: Bool) {
		let pending = state.withLock { state -> [String] in
			guard case .pending(let lines) = state.sink else { return [] }
			state.sink = enabled ? .log(log) : .disabled
			return enabled ? lines : []
		}
		for line in pending {
			log.debug(line)
		}
	}

	package func mark(_ milestone: String) {
		record("Startup: \(milestone)")
	}

	package func beginStep(_ name: String) {
		record("Startup: step \(name) start")
	}

	package func endStep(_ name: String) {
		record("Startup: step \(name) end")
	}

	package func artworkVisible(cached: Bool) {
		record("Startup: hero artwork visible (\(cached ? "cache" : "no cache"))")
	}

	private func record(_ message: String) {
		let milliseconds = max(0, Int(Date().timeIntervalSince(startedAt) * 1000))
		let line = "\(message) +\(milliseconds) ms"
		state.withLock { state in
			switch state.sink {
			case .disabled:
				return
			case .pending(var lines):
				guard state.loggedMessages.insert(message).inserted else { return }
				lines.append(line)
				state.sink = .pending(lines)
			case .log(let log):
				guard state.loggedMessages.insert(message).inserted else { return }
				log.debug(line)
			}
		}
	}

	// `kp_proc.p_starttime` is the wall-clock start the kernel recorded, which includes dyld.
	private static func processStartDate() -> Date? {
		var info = kinfo_proc()
		var size = MemoryLayout<kinfo_proc>.stride
		var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
		let result = mib.withUnsafeMutableBufferPointer { buffer in
			sysctl(buffer.baseAddress, UInt32(buffer.count), &info, &size, nil, 0)
		}
		guard result == 0, size > 0 else { return nil }
		let start = info.kp_proc.p_starttime
		return Date(
			timeIntervalSince1970: TimeInterval(start.tv_sec)
				+ TimeInterval(start.tv_usec) / 1_000_000
		)
	}
}
