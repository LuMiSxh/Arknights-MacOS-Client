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
	func leaseCanBeReleasedAndReacquiredInOneProcess() throws {
		let root = FileManager.default.temporaryDirectory.appending(
			path: "InstallerDirectoryTests-reacquire-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		defer { try? FileManager.default.removeItem(at: root) }

		let first = try InstallLease.acquire(at: root)
		first.release()
		let second = try InstallLease.acquire(at: root)
		second.release()
		try withInstallLease(at: root) { _ in }
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
	}

	@Test
	func scopedLeaseIsReleasedWhenTheBodyThrows() throws {
		struct Failure: Error {}
		let root = FileManager.default.temporaryDirectory.appending(
			path: "InstallerDirectoryTests-throw-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		defer { try? FileManager.default.removeItem(at: root) }

		#expect(throws: Failure.self) {
			try withInstallLease(at: root) { _ in throw Failure() }
		}
		try withInstallLease(at: root) { _ in }
	}

	@Test
	func openedParentDescriptorDoesNotFollowAReplacementSymlink() throws {
		let manager = FileManager.default
		let rootURL = manager.temporaryDirectory.appending(
			path: "InstallerDirectoryTests-parent-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		let movedDirectory = rootURL.appending(path: "bin-original", directoryHint: .isDirectory)
		let outside = manager.temporaryDirectory.appending(
			path: "InstallerDirectoryTests-outside-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		defer {
			try? manager.removeItem(at: rootURL)
			try? manager.removeItem(at: outside)
		}
		try manager.createDirectory(at: outside, withIntermediateDirectories: true)
		try withInstallLease(at: rootURL) { lease in
			let install = lease.directory
			let destination = try install.file(at: "bin/game.dat", createParents: true)

			try manager.moveItem(at: rootURL.appending(path: "bin"), to: movedDirectory)
			try manager.createSymbolicLink(
				at: rootURL.appending(path: "bin"), withDestinationURL: outside)
			let descriptor = try destination.open(
				flags: O_WRONLY | O_CREAT | O_NOFOLLOW | O_CLOEXEC,
				mode: 0o600
			)
			defer { _ = close(descriptor) }
			let expected = Data("anchored".utf8)
			try expected.withUnsafeBytes { bytes in
				guard let base = bytes.baseAddress else { return }
				guard write(descriptor, base, bytes.count) == bytes.count else {
					throw POSIXError(.init(rawValue: errno) ?? .EIO)
				}
			}

			#expect(try Data(contentsOf: movedDirectory.appending(path: "game.dat")) == expected)
			#expect(!manager.fileExists(atPath: outside.appending(path: "game.dat").path))
		}
	}

	@Test
	func exclusiveRestoreKeepsBothQuarantineAndConcurrentReplacement() throws {
		let root = FileManager.default.temporaryDirectory.appending(
			path: "InstallerDirectoryTests-restore-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		defer { try? FileManager.default.removeItem(at: root) }
		try withInstallLease(at: root) { lease in
			let install = lease.directory
			let staging = try install.stagingDirectory(
				named: "staging"
			)
			let quarantine = staging.file(named: "download.part.quarantine")
			let replacement = install.root.file(named: "download.part")
			let retained = Data("verified quarantine".utf8)
			let concurrent = Data("concurrent replacement".utf8)
			try retained.write(to: quarantine.url)
			try concurrent.write(to: replacement.url)

			do {
				try quarantine.renameExclusively(to: replacement)
				Issue.record("Expected exclusive restore to preserve an occupied destination")
			} catch let error as POSIXError {
				#expect(error.code == .EEXIST)
			} catch {
				Issue.record("Unexpected exclusive restore error: \(error)")
			}

			#expect(try Data(contentsOf: quarantine.url) == retained)
			#expect(try Data(contentsOf: replacement.url) == concurrent)
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
