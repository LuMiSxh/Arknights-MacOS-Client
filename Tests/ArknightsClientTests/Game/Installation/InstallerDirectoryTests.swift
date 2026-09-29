// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation
import Testing

@testable import ArknightsClient

@Suite(.serialized)
struct InstallerDirectoryTests {
	@Test
	func installationLeaseIsProcessSharedAndReleasedWhenAProcessExits() throws {
		let root = FileManager.default.temporaryDirectory.appending(
			path: "InstallerDirectoryTests-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		defer { try? FileManager.default.removeItem(at: root) }

		try withLease(at: root) {
			let lockAttempt = try childLockAttempt(at: root, killAfterAcquire: false)
			#expect(lockAttempt == .blocked)
		}

		let killedChild = try childLockAttempt(at: root, killAfterAcquire: true)
		#expect(killedChild == .killed)
		let leaseAfterChildExit = try InstallerInstallDirectory(at: root)
		#expect(leaseAfterChildExit.url == root.standardizedFileURL)
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
		let install = try InstallerInstallDirectory(at: rootURL)
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

	@Test
	func exclusiveRestoreKeepsBothQuarantineAndConcurrentReplacement() throws {
		let root = FileManager.default.temporaryDirectory.appending(
			path: "InstallerDirectoryTests-restore-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		defer { try? FileManager.default.removeItem(at: root) }
		let install = try InstallerInstallDirectory(at: root)
		let staging = try install.stagingDirectory(
			named: AppConstants.Game.installerStagingDirectoryName
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

	@Test
	func privateStagingClearsInheritedDirectoryAndFileACLs() throws {
		let fixture = try GameInstallerStreamingTests.makeFixture(body: Data("game".utf8))
		defer { fixture.remove() }
		let rootURL = fixture.directory
		let install = try InstallerInstallDirectory(at: rootURL)
		let chmod = Process()
		chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
		chmod.arguments = [
			"+a",
			"everyone allow add_file,delete_child,directory_inherit,file_inherit",
			rootURL.path,
		]
		try chmod.run()
		chmod.waitUntilExit()
		#expect(chmod.terminationStatus == 0)

		let inheritedProbe = try install.root.openDirectory(
			named: "acl-probe",
			create: true,
			mode: 0o700
		)
		let inheritedACL = acl_get_fd_np(inheritedProbe.descriptor, ACL_TYPE_EXTENDED)
		#expect(inheritedACL != nil)
		if let inheritedACL {
			var entry: acl_entry_t?
			#expect(acl_get_entry(inheritedACL, 0, &entry) == 0)
			_ = acl_free(UnsafeMutableRawPointer(inheritedACL))
		}

		let staging = try install.stagingDirectory(
			named: AppConstants.Game.installerStagingDirectoryName
		)
		var stagingStatus = stat()
		#expect(fstat(staging.descriptor, &stagingStatus) == 0)
		#expect(stagingStatus.st_uid == geteuid())
		#expect(stagingStatus.st_mode & 0o777 == 0o700)
		let stagingACL = acl_get_fd_np(staging.descriptor, ACL_TYPE_EXTENDED)
		#expect(stagingACL == nil)
		#expect(errno == ENOENT)

		let stagedFile = try staging.file(named: "payload").open(
			flags: O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
			mode: 0o600
		)
		defer { _ = close(stagedFile) }
		let stagedFileACL = acl_get_fd_np(stagedFile, ACL_TYPE_EXTENDED)
		#expect(stagedFileACL == nil)
		#expect(errno == ENOENT)

		var stagingBeforeState = stat()
		#expect(fstat(staging.descriptor, &stagingBeforeState) == 0)
		try fixture.installer.saveState(
			configuration: fixture.configuration,
			manifest: GameManifest(source: fixture.source, file: [fixture.item]),
			to: install
		)
		var stagingAfterState = stat()
		#expect(fstat(staging.descriptor, &stagingAfterState) == 0)
		#expect(
			stagingAfterState.st_mtimespec.tv_sec != stagingBeforeState.st_mtimespec.tv_sec
				|| stagingAfterState.st_mtimespec.tv_nsec != stagingBeforeState.st_mtimespec.tv_nsec
		)
		#expect(try fixture.installer.loadState(from: install) != nil)
		let state = install.root.file(named: AppConstants.Game.installedStateFileName)
		let stateDescriptor = try state.open(flags: O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
		defer { _ = close(stateDescriptor) }
		let stateACL = acl_get_fd_np(stateDescriptor, ACL_TYPE_EXTENDED)
		#expect(stateACL == nil)
		#expect(errno == ENOENT)
	}

	private func withLease(at root: URL, operation: () throws -> Void) throws {
		let lease = try InstallerInstallDirectory(at: root)
		try operation()
		withExtendedLifetime(lease) {}
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
