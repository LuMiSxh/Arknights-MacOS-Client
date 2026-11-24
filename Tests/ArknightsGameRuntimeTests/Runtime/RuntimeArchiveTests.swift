// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameRuntime

struct RuntimeArchiveTests {
	private func write(_ builder: TarBuilder, to directory: URL) throws -> URL {
		let archive = directory.appending(path: "runtime.tar.xz")
		try xzCompressed(builder.data).write(to: archive)
		return archive
	}

	@Test
	func extractsTheSingleTopLevelRuntimeDirectory() throws {
		let temporary = try TemporaryDirectory("RuntimeArchiveExtract")
		defer { temporary.remove() }
		var builder = TarBuilder()
		builder.directory("Runtime")
		builder.append(name: "Runtime/bin/Arknights", content: Data("launcher".utf8))
		builder.append(name: "Runtime/DXMT/x64/d3d11.dll", content: Data("dxmt".utf8))
		builder.append(name: "Runtime/Licenses/MIT.txt", content: Data("mit".utf8))
		builder.append(name: "Runtime/NOTICE.md", content: Data("notice".utf8))
		builder.finish()
		let archive = try write(builder, to: temporary.url)

		let destination = temporary.url.appending(path: "staging", directoryHint: .isDirectory)
		let root = try RuntimeArchive.extract(at: archive, into: destination)

		#expect(root == destination.appending(path: "Runtime", directoryHint: .isDirectory))
		for path in ["bin/Arknights", "DXMT/x64/d3d11.dll", "Licenses/MIT.txt", "NOTICE.md"] {
			#expect(FileManager.default.fileExists(atPath: root.appending(path: path).path))
		}
	}

	@Test(arguments: [
		(names: ["Runtime/bin/a", "NOTICE.md"], root: "Runtime"),
		(names: ["Runtime/bin/a", "Licenses/MIT.txt"], root: "Runtime"),
		(names: ["Libraries/bin/a"], root: "Runtime"),
		(names: ["Runtime/bin/a"], root: "Delta"),
	])
	func requiresExactlyTheExpectedTopLevelDirectory(names: [String], root: String) throws {
		let temporary = try TemporaryDirectory("RuntimeArchiveRoot")
		defer { temporary.remove() }
		var builder = TarBuilder()
		for name in names { builder.append(name: name) }
		builder.finish()
		let archive = try write(builder, to: temporary.url)

		#expect(throws: RuntimeArchiveError.notSingleTopLevelDirectory) {
			_ = try RuntimeArchive.extract(
				at: archive,
				into: temporary.url.appending(path: "staging", directoryHint: .isDirectory),
				expectedRoot: root)
		}
	}

	@Test(arguments: ["/etc/evil", "Runtime/../../evil", "C:\\evil", "C:/evil"])
	func rejectsUnsafePaths(name: String) throws {
		let temporary = try TemporaryDirectory("RuntimeArchiveUnsafePath")
		defer { temporary.remove() }
		var builder = TarBuilder()
		builder.append(name: name)
		builder.finish()
		let archive = try write(builder, to: temporary.url)

		#expect(throws: RuntimeArchiveError.unsafePath(name)) {
			_ = try RuntimeArchive.extract(
				at: archive,
				into: temporary.url.appending(path: "staging", directoryHint: .isDirectory))
		}
	}

	@Test(arguments: ["__MACOSX/._thing", "Runtime/._resource"])
	func rejectsPlatformMetadata(name: String) throws {
		let temporary = try TemporaryDirectory("RuntimeArchiveMetadata")
		defer { temporary.remove() }
		var builder = TarBuilder()
		builder.append(name: name)
		builder.finish()
		let archive = try write(builder, to: temporary.url)

		#expect(throws: RuntimeArchiveError.platformMetadata(name)) {
			_ = try RuntimeArchive.extract(
				at: archive,
				into: temporary.url.appending(path: "staging", directoryHint: .isDirectory))
		}
	}

	@Test(arguments: [
		(
			typeFlag: UInt8(0x32), linkName: "/etc/evil",
			failure: RuntimeArchiveError.escapingLink("/etc/evil")
		),
		(
			typeFlag: UInt8(0x32), linkName: "../../outside",
			failure: RuntimeArchiveError.escapingLink("../../outside")
		),
		(
			typeFlag: UInt8(0x31), linkName: "Runtime/bin/a",
			failure: RuntimeArchiveError.unsupportedEntry("Runtime/bin/hard")
		),
	])
	func rejectsLinksThatEscapeTheRootAndHardLinks(
		typeFlag: UInt8, linkName: String, failure: RuntimeArchiveError
	) throws {
		let temporary = try TemporaryDirectory("RuntimeArchiveLinks")
		defer { temporary.remove() }
		var builder = TarBuilder()
		builder.directory("Runtime")
		builder.append(name: "Runtime/bin/a")
		builder.append(name: "Runtime/bin/hard", typeFlag: typeFlag, linkName: linkName)
		builder.finish()
		let archive = try write(builder, to: temporary.url)

		#expect(throws: failure) {
			_ = try RuntimeArchive.extract(
				at: archive,
				into: temporary.url.appending(path: "staging", directoryHint: .isDirectory))
		}
	}

	@Test
	func rejectsATruncatedXZStream() throws {
		let temporary = try TemporaryDirectory("RuntimeArchiveTruncated")
		defer { temporary.remove() }
		var builder = TarBuilder()
		builder.append(name: "Runtime/bin/a", content: Data(repeating: 7, count: 4_096))
		builder.finish()
		let archive = temporary.url.appending(path: "runtime.tar.xz")
		try xzCompressed(builder.data).dropLast(16).write(to: archive)

		#expect(throws: RuntimeArchiveError.self) {
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
		builder.directory("Runtime")
		builder.append(name: "Runtime/bin/wine64", mode: 0o755, content: Data("wine64".utf8))
		builder.finish()
		let archive = try write(builder, to: temporary.url)

		let root = try RuntimeArchive.extract(
			at: archive,
			into: temporary.url.appending(path: "staging", directoryHint: .isDirectory))

		#expect(
			FileManager.default.isExecutableFile(
				atPath: root.appending(path: "bin/wine64").path))
	}
}
