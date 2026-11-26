// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation
import Synchronization

/// Startup instrumentation. Logs each launch milestone once at debug level, measured from the
/// kernel's process start time, so a start can be checked against the one-second goal.
///
/// Milestones are buffered until `attach(_:)`; `LauncherLog` applies the debug gate.
/// Read them with
/// `grep 'startup-milestone' ~/Library/Logs/com.lumisxh.arknights-client/launcher.log`.
package final class StartupTimeline: Sendable {
	private struct Milestone: Sendable {
		let name: String
		let elapsedMilliseconds: Int
	}

	private enum Sink {
		case pending([Milestone])
		case log(LauncherLog)
	}

	private struct State {
		var sink = Sink.pending([])
		var loggedMessages: Set<String> = []
	}

	package static let shared = StartupTimeline()

	private let state = Mutex(State())
	private let clock = ContinuousClock()
	private let origin: ContinuousClock.Instant
	private let originMilliseconds: Int

	private init() {
		origin = clock.now
		let startedAt = Self.processStartDate() ?? Date()
		originMilliseconds = max(0, Int(Date().timeIntervalSince(startedAt) * 1000))
	}

	/// Connects the shared timeline to the launcher log and flushes anything recorded earlier.
	package func attach(_ log: LauncherLog) {
		let pending = state.withLock { state -> [Milestone] in
			guard case .pending(let milestones) = state.sink else { return [] }
			state.sink = .log(log)
			return milestones
		}
		for milestone in pending {
			log.debug(
				.app, "startup-milestone",
				["name": milestone.name, "elapsedMs": milestone.elapsedMilliseconds])
		}
	}

	package func mark(_ milestone: String) {
		record(milestone)
	}

	package func beginStep(_ name: String) {
		record("step \(name) start")
	}

	package func endStep(_ name: String) {
		record("step \(name) end")
	}

	package func artworkVisible(cached: Bool) {
		record("hero artwork visible (\(cached ? "cache" : "no cache"))")
	}

	private func record(_ name: String) {
		let elapsed = origin.duration(to: clock.now)
		let milliseconds =
			originMilliseconds + Int(elapsed.components.seconds * 1000)
			+ Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
		state.withLock { state in
			guard state.loggedMessages.insert(name).inserted else { return }
			switch state.sink {
			case .pending(var milestones):
				milestones.append(
					Milestone(name: name, elapsedMilliseconds: milliseconds))
				state.sink = .pending(milestones)
			case .log(let log):
				log.debug(
					.app, "startup-milestone",
					["name": name, "elapsedMs": milliseconds])
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
