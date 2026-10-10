// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Darwin
import Foundation
import Testing

@testable import ArknightsGameInstallation
@testable import ArknightsInfrastructure

@Suite(.serialized)
struct InstallerStateACLTests {
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
}
