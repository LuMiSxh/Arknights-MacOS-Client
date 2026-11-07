// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameRuntime

/// Builds a plain, uncompressed tar archive so path-safety tests do not need gzip fixtures.
private struct TarBuilder {
	private(set) var data = Data()

	mutating func append(
		name: String,
		typeFlag: UInt8 = 0x30,
		linkName: String = "",
		mode: Int = 0o644,
		content: Data = Data()
	) {
		var header = [UInt8](repeating: 0, count: 512)
		writeString(name, into: &header, range: 0..<100)
		writeOctal(mode, into: &header, range: 100..<108)
		writeOctal(content.count, into: &header, range: 124..<136)
		header[156] = typeFlag
		writeString(linkName, into: &header, range: 157..<257)
		data.append(contentsOf: header)
		data.append(content)
		let padding = (512 - (content.count % 512)) % 512
		if padding > 0 { data.append(Data(repeating: 0, count: padding)) }
	}

	mutating func directory(_ name: String) {
		append(name: name, typeFlag: 0x35)
	}

	mutating func pax(_ records: [String: String]) {
		var payload = ""
		for (key, value) in records {
			let body = "\(key)=\(value)\n"
			var length = body.utf8.count + 2
			while "\(length)".utf8.count + 1 + body.utf8.count != length {
				length += 1
			}
			payload += "\(length) \(body)"
		}
		append(name: "././@PaxHeader", typeFlag: 0x78, content: Data(payload.utf8))
	}

	mutating func finish() {
		data.append(Data(repeating: 0, count: 1_024))
	}

	private func writeString(_ value: String, into header: inout [UInt8], range: Range<Int>) {
		let bytes = Array(value.utf8)
		for (index, byte) in bytes.enumerated() where index < range.count {
			header[range.lowerBound + index] = byte
		}
	}

	private func writeOctal(_ value: Int, into header: inout [UInt8], range: Range<Int>) {
		let text = String(value, radix: 8)
		let bytes = Array(text.utf8)
		for (index, byte) in bytes.enumerated() where index < range.count {
			header[range.lowerBound + index] = byte
		}
	}
}

struct RuntimeArchiveTests {
	@Test
	func extractsTheSingleTopLevelRuntimeDirectory() throws {
		let temporary = try TemporaryDirectory("RuntimeArchiveExtract")
		defer { temporary.remove() }
		var builder = TarBuilder()
		builder.directory("Libraries")
		builder.append(name: "Libraries/Wine/bin/Arknights", content: Data("launcher".utf8))
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
				atPath: root.appending(path: "Wine/bin/Arknights").path))
		#expect(
			FileManager.default.fileExists(
				atPath: root.appending(path: "DXMT/x64/d3d11.dll").path))
	}

	@Test
	func acceptsPaxExtendedHeaders() throws {
		let temporary = try TemporaryDirectory("RuntimeArchivePax")
		defer { temporary.remove() }
		var builder = TarBuilder()
		builder.directory("Libraries")
		builder.pax([
			"mtime": "1793961641.027845",
			"path": "Libraries/Wine/bin/Arknights",
		])
		builder.append(name: "short-name", content: Data("launcher".utf8))
		builder.finish()
		let archive = temporary.url.appending(path: "runtime.tar")
		try builder.data.write(to: archive)

		let destination = temporary.url.appending(path: "staging", directoryHint: .isDirectory)
		let root = try RuntimeArchive.extract(at: archive, into: destination)

		#expect(root == destination.appending(path: "Libraries", directoryHint: .isDirectory))
		#expect(
			FileManager.default.fileExists(
				atPath: root.appending(path: "Wine/bin/Arknights").path))
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

	@Test
	func rejectsAnEscapingSymlink() throws {
		let temporary = try TemporaryDirectory("RuntimeArchiveSymlink")
		defer { temporary.remove() }
		var builder = TarBuilder()
		builder.directory("Libraries")
		builder.append(name: "Libraries/bin/Arknights", typeFlag: 0x32, linkName: "/etc/evil")
		builder.finish()
		let archive = temporary.url.appending(path: "runtime.tar")
		try builder.data.write(to: archive)

		#expect(throws: RuntimeArchiveError.escapingLink("/etc/evil")) {
			_ = try RuntimeArchive.extract(
				at: archive,
				into: temporary.url.appending(path: "staging", directoryHint: .isDirectory))
		}
	}

	@Test
	func rejectsAHardLinkOutsideTheArchive() throws {
		let temporary = try TemporaryDirectory("RuntimeArchiveHardLink")
		defer { temporary.remove() }
		var builder = TarBuilder()
		builder.directory("Libraries")
		builder.append(name: "Libraries/bin/hard", typeFlag: 0x31, linkName: "../../outside")
		builder.finish()
		let archive = temporary.url.appending(path: "runtime.tar")
		try builder.data.write(to: archive)

		#expect(throws: RuntimeArchiveError.escapingLink("../../outside")) {
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

	@Test
	func extractsAGzipCompressedArchive() throws {
		let temporary = try TemporaryDirectory("RuntimeArchiveGzip")
		defer { temporary.remove() }
		var builder = TarBuilder()
		builder.directory("Libraries")
		builder.append(name: "Libraries/Wine/bin/Arknights", content: Data("launcher".utf8))
		builder.finish()
		let tar = temporary.url.appending(path: "runtime.tar")
		try builder.data.write(to: tar)

		let archive = temporary.url.appending(path: "runtime.tar.gz")
		guard FileManager.default.createFile(atPath: archive.path, contents: nil) else {
			throw CocoaError(.fileWriteUnknown)
		}
		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/gzip")
		process.arguments = ["-c", tar.path]
		process.standardOutput = try FileHandle(forWritingTo: archive)
		try process.run()
		process.waitUntilExit()
		#expect(process.terminationStatus == 0)

		let destination = temporary.url.appending(path: "staging", directoryHint: .isDirectory)
		let root = try RuntimeArchive.extract(at: archive, into: destination)
		#expect(root == destination.appending(path: "Libraries", directoryHint: .isDirectory))
		#expect(
			FileManager.default.fileExists(
				atPath: root.appending(path: "Wine/bin/Arknights").path))
	}
}
