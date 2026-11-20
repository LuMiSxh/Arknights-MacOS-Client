// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameInstallation

/// A folder the user chose may hold their own files, so uninstalling removes only game files.
@Suite(.serialized)
struct GameInstallerUninstallTests {
	private let fileManager = FileManager.default

	@Test
	func uninstallRemovesOnlyTheInstalledFilesFromAChosenFolder() async throws {
		let body = Data("game".utf8)
		let fixture = try InstallerFixture.make(body: body)
		defer { fixture.remove() }
		fixture.route.handler = { request in
			(makeHTTPResponse(url: request.url!, status: 200), body)
		}
		_ = try await fixture.install()
		let notes = fixture.directory.appending(path: "notes.txt")
		let nested = fixture.directory.appending(path: "keep/user.txt")
		let outside = fixture.temporary.url.appending(path: "outside.txt")
		let link = fixture.directory.appending(path: "link.txt")
		try fileManager.createDirectory(
			at: nested.deletingLastPathComponent(), withIntermediateDirectories: true)
		try Data("n".utf8).write(to: notes)
		try Data("u".utf8).write(to: nested)
		try Data("o".utf8).write(to: outside)
		try fileManager.createSymbolicLink(at: link, withDestinationURL: outside)

		let outcome = try await fixture.installer.uninstall(
			from: fixture.directory, scope: .installedFilesOnly)

		#expect(outcome == .removed)
		#expect(!fileManager.fileExists(atPath: fixture.destination.path))
		#expect(
			!fileManager.fileExists(atPath: fixture.destination.deletingLastPathComponent().path))
		#expect(
			!fileManager.fileExists(
				atPath: fixture.directory.appending(path: AppConstants.Game.installedStateFileName)
					.path
			))
		#expect(try Data(contentsOf: notes) == Data("n".utf8))
		#expect(try Data(contentsOf: nested) == Data("u".utf8))
		#expect(try Data(contentsOf: outside) == Data("o".utf8))
		#expect(try fileManager.destinationOfSymbolicLink(atPath: link.path) == outside.path)
	}

	@Test
	func uninstallWithoutAFileListRemovesOnlyTheLaunchersWorkingFiles() async throws {
		let fixture = try InstallerFixture.make(body: Data("game".utf8))
		defer { fixture.remove() }
		let executable = fixture.directory.appending(path: "Arknights.exe")
		let notes = fixture.directory.appending(path: "notes.txt")
		try Data("x".utf8).write(to: executable)
		try Data("n".utf8).write(to: notes)
		let unrelatedPartial = fixture.directory.appending(path: "notes.part")
		let staging = fixture.directory.appending(
			path: AppConstants.Game.installerStagingDirectoryName, directoryHint: .isDirectory)
		try Data("p".utf8).write(to: unrelatedPartial)
		try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)

		let outcome = try await fixture.installer.uninstall(
			from: fixture.directory, scope: .installedFilesOnly)

		#expect(outcome == .installedFilesUnknown)
		#expect(!fileManager.fileExists(atPath: staging.path))
		#expect(fileManager.fileExists(atPath: unrelatedPartial.path))
		#expect(fileManager.fileExists(atPath: executable.path))
		#expect(fileManager.fileExists(atPath: notes.path))
	}

	@Test
	func uninstallKeepsAnUnreadableInstalledStateFile() async throws {
		let fixture = try InstallerFixture.make(body: Data("game".utf8))
		defer { fixture.remove() }
		let state = fixture.directory.appending(path: AppConstants.Game.installedStateFileName)
		let corrupt = Data("not json".utf8)
		try corrupt.write(to: state)

		let outcome = try await fixture.installer.uninstall(
			from: fixture.directory, scope: .installedFilesOnly)

		#expect(outcome == .installedFilesUnknown)
		#expect(try Data(contentsOf: state) == corrupt)
	}
}
