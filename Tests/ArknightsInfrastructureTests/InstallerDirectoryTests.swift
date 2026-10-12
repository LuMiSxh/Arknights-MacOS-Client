// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation
import Testing

@testable import ArknightsInfrastructure

@Suite(.serialized)
struct InstallerDirectoryTests {
	@Test
	func installationLeaseIsProcessSharedAndReleasedWhenAProcessExits() throws {
		let root = FileManager.default.temporaryDirectory.appending(
			path: "InstallerDirectoryTests-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		defer { try? FileManager.default.removeItem(at: root) }

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

	@Test
	func secondAcquireWhileHeldThrowsDirectoryInUse() throws {
		let root = FileManager.default.temporaryDirectory.appending(
			path: "InstallerDirectoryTests-busy-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		defer { try? FileManager.default.removeItem(at: root) }

		let held = try InstallLease.acquire(at: root)
		do {
			_ = try InstallLease.acquire(at: root)
			Issue.record("Expected the second acquire to throw directoryInUse")
		} catch InstallerFileSystemError.directoryInUse {
		} catch {
			Issue.record("Unexpected error: \(error)")
		}
		held.release()
		try withInstallLease(at: root) { _ in }

		struct Failure: Error {}
		#expect(throws: Failure.self) {
			try withInstallLease(at: root) { _ in throw Failure() }
		}
		try withInstallLease(at: root) { _ in }
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
