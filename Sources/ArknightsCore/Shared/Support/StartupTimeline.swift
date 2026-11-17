// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation
import Synchronization

/// Temporary startup instrumentation. Logs each launch milestone once, measured from the
/// kernel's process start time, so a normal start can be checked against the one-second goal.
///
/// Remove this type with its call sites once startup is verified: `grep -rn StartupTimeline
/// Sources` and `grep 'Startup:' ~/Library/Logs/com.lumisxh.arknights-client/launcher.log`.
package final class StartupTimeline: Sendable {
	private struct State {
		var log: LauncherLog?
		var pending: [String] = []
		var loggedMessages: Set<String> = []
	}

	package static let shared = StartupTimeline()

	private let state = Mutex(State())
	private let startedAt: Date

	private init() {
		startedAt = Self.processStartDate() ?? Date()
	}

	/// Connects the shared timeline to the launcher log and flushes anything recorded earlier.
	package func attach(_ log: LauncherLog) {
		let pending = state.withLock { state -> [String] in
			state.log = log
			let pending = state.pending
			state.pending.removeAll()
			return pending
		}
		for line in pending {
			log.info(line)
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
			guard state.loggedMessages.insert(message).inserted else { return }
			guard let log = state.log else {
				state.pending.append(line)
				return
			}
			log.info(line)
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
