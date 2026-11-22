// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameRuntime

struct RuntimeArchiveTests {
	@Test
	func extractsTheSingleTopLevelRuntimeDirectory() throws {
		let temporary = try TemporaryDirectory("RuntimeArchiveExtract")
		defer { temporary.remove() }
		var builder = TarBuilder()
		builder.directory("Libraries")
		builder.append(name: "Libraries/Wine/bin/wine64", content: Data("launcher".utf8))
		builder.append(name: "Libraries/DXMT/x64/d3d11.dll", content: Data("dxmt".utf8))
		builder.append(name: "Licenses/MIT.txt", content: Data("mit".utf8))
		builder.append(name: "NOTICE.md", content: Data("notice".utf8))
		builder.finish()
		let archive = temporary.url.appending(path: "runtime.tar")
		try builder.data.write(to: archive)

		let destination = temporary.url.appending(path: "staging", directoryHint: .isDirectory)
		let root = try RuntimeArchive.extract(at: archive, into: destination)

		#expect(root == destination.appending(path: "Libraries", directoryHint: .isDirectory))
		#expect(
			FileManager.default.fileExists(
				atPath: root.appending(path: "Wine/bin/wine64").path))
		#expect(
			FileManager.default.fileExists(
				atPath: root.appending(path: "DXMT/x64/d3d11.dll").path))
	}

	@Test(arguments: ["/etc/evil", "Libraries/../../evil", "C:\\evil", "C:/evil"])
	func rejectsUnsafePaths(name: String) throws {
		let temporary = try TemporaryDirectory("RuntimeArchiveUnsafePath")
		defer { temporary.remove() }
		var builder = TarBuilder()
		builder.append(name: name)
		builder.finish()
		let archive = temporary.url.appending(path: "runtime.tar")
		try builder.data.write(to: archive)

		#expect(throws: RuntimeArchiveError.unsafePath(name)) {
			_ = try RuntimeArchive.extract(
				at: archive,
				into: temporary.url.appending(path: "staging", directoryHint: .isDirectory))
		}
	}

	@Test(arguments: ["__MACOSX/._thing", "Libraries/._resource"])
	func rejectsPlatformMetadata(name: String) throws {
		let temporary = try TemporaryDirectory("RuntimeArchiveMetadata")
		defer { temporary.remove() }
		var builder = TarBuilder()
		builder.append(name: name)
		builder.finish()
		let archive = temporary.url.appending(path: "runtime.tar")
		try builder.data.write(to: archive)

		#expect(throws: RuntimeArchiveError.platformMetadata(name)) {
			_ = try RuntimeArchive.extract(
				at: archive,
				into: temporary.url.appending(path: "staging", directoryHint: .isDirectory))
		}
	}

	@Test(arguments: [
		(typeFlag: UInt8(0x32), name: "Libraries/bin/wine64", linkName: "/etc/evil"),
		(typeFlag: UInt8(0x31), name: "Libraries/bin/hard", linkName: "../../outside"),
	])
	func rejectsLinksOutsideTheArchive(typeFlag: UInt8, name: String, linkName: String) throws {
		let temporary = try TemporaryDirectory("RuntimeArchiveLinks")
		defer { temporary.remove() }
		var builder = TarBuilder()
		builder.directory("Libraries")
		builder.append(name: name, typeFlag: typeFlag, linkName: linkName)
		builder.finish()
		let archive = temporary.url.appending(path: "runtime.tar")
		try builder.data.write(to: archive)

		#expect(throws: RuntimeArchiveError.escapingLink(linkName)) {
			_ = try RuntimeArchive.extract(
				at: archive,
				into: temporary.url.appending(path: "staging", directoryHint: .isDirectory))
		}
	}

	@Test
	func preservesExecutablePermissions() throws {
		let temporary = try TemporaryDirectory("RuntimeArchiveMode")
		defer { temporary.remove() }
		var builder = TarBuilder()
		builder.directory("Libraries")
		builder.append(
			name: "Libraries/bin/wine64", mode: 0o755, content: Data("wine64".utf8))
		builder.finish()
		let archive = temporary.url.appending(path: "runtime.tar")
		try builder.data.write(to: archive)

		let destination = temporary.url.appending(path: "staging", directoryHint: .isDirectory)
		let root = try RuntimeArchive.extract(at: archive, into: destination)

		#expect(
			FileManager.default.isExecutableFile(
				atPath: root.appending(path: "bin/wine64").path))
	}
}
