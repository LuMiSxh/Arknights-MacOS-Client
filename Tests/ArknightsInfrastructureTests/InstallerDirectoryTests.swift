// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Darwin
import Foundation
import Testing

@testable import ArknightsInfrastructure

@Suite
struct InstallerDirectoryTests {
	/// A held lease excludes other processes, and a process that dies while holding it releases it.
	@Test
	func installLeaseExcludesOtherProcessesAndIsReleasedWhenTheHolderDies() throws {
		let directory = try TemporaryDirectory("InstallerDirectoryTests")
		defer { directory.remove() }
		let root = directory.url

		try withInstallLease(at: root) { _ in
			let lockAttempt = try childLockAttempt(at: root, killAfterAcquire: false)
			#expect(lockAttempt == .blocked)
		}

		let killedChild = try childLockAttempt(at: root, killAfterAcquire: true)
		#expect(killedChild == .killed)
		try withInstallLease(at: root) { lease in
			#expect(lease.directory.url == root.standardizedFileURL)
		}
	}

	private enum LockProbeResult: Equatable {
		case blocked
		case killed
	}

	private func childLockAttempt(
		at root: URL,
		killAfterAcquire: Bool
	) throws -> LockProbeResult {
		let script =
			killAfterAcquire
			? "import fcntl, os, signal, sys; fd=os.open(sys.argv[1], os.O_RDONLY | os.O_DIRECTORY); fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB); os.kill(os.getpid(), signal.SIGKILL)"
			: "import errno, fcntl, os, sys; fd=os.open(sys.argv[1], os.O_RDONLY | os.O_DIRECTORY);\ntry: fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)\nexcept OSError as error: sys.exit(1 if error.errno in (errno.EAGAIN, errno.EWOULDBLOCK) else 2)\nsys.exit(0)"
		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
		process.arguments = ["-c", script, root.path]
		try process.run()
		process.waitUntilExit()
		if killAfterAcquire {
			return process.terminationReason == .uncaughtSignal
				&& process.terminationStatus == SIGKILL
				? .killed : .blocked
		}
		return process.terminationReason == .exit && process.terminationStatus == 1
			? .blocked : .killed
	}
}
