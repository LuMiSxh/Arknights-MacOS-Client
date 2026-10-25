// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsInfrastructure

struct DiagnosticsBundleTests {
	private let baseName = "DiagnosticsBundleTests"
	private let redaction = DiagnosticsRedaction(homeDirectory: "/Users/tester", userName: "tester")

	/// The archive carries every item plus the readme, and the staging folder stays out of it.
	@Test
	func writesAnArchiveWithTheItemsAndTheReadme() async throws {
		let directory = try TemporaryDirectory("DiagnosticsBundleTests")
		defer { directory.remove() }
		let source = directory.url.appending(path: "launcher.log")
		try Data("line\n".utf8).write(to: source)
		let output = directory.url.appending(path: "out")

		let archive = try await DiagnosticsBundle.write(
			[
				.init(archivePath: "Logs/launcher.log", content: .file(source)),
				.init(archivePath: "environment.txt", content: .text("macOS 27\n")),
			],
			readme: "# Readme",
			named: baseName,
			to: output,
			redaction: redaction,
			reportCleanupFailure: { _ in }
		)
		let second = try await DiagnosticsBundle.write(
			[], readme: "", named: baseName, to: output,
			redaction: redaction, reportCleanupFailure: { _ in })
		#expect(second.lastPathComponent == "\(baseName)-2.zip")
		#expect(FileManager.default.fileExists(atPath: archive.path))

		#expect(archive.lastPathComponent == "\(baseName).zip")
		let extracted = directory.url.appending(path: "extracted")
		try extract(archive, into: extracted)
		#expect(
			try String(
				contentsOf: extracted.appending(path: "Logs/launcher.log"), encoding: .utf8)
				== "line\n")
		#expect(
			try String(contentsOf: extracted.appending(path: "environment.txt"), encoding: .utf8)
				== "macOS 27\n")
		#expect(
			try String(contentsOf: extracted.appending(path: "README.md"), encoding: .utf8)
				== "# Readme")
	}

	/// An unsafe path or a missing source fails the write and leaves nothing behind.
	@Test(arguments: ["../escape.txt", "/escape.txt", ".", "Logs/missing.log"])
	func rejectsABadItemAndLeavesNothingBehind(archivePath: String) async throws {
		let directory = try TemporaryDirectory("DiagnosticsBundleTests")
		defer { directory.remove() }

		await #expect(throws: DiagnosticsBundleError.self) {
			try await DiagnosticsBundle.write(
				[
					.init(
						archivePath: archivePath,
						content: .file(directory.url.appending(path: "missing.log")))
				],
				readme: "",
				named: baseName,
				to: directory.url,
				redaction: redaction,
				reportCleanupFailure: { _ in }
			)
		}
		#expect(try FileManager.default.contentsOfDirectory(atPath: directory.url.path).isEmpty)
	}

	/// Home path, user name, and URL queries are removed from a log that spans several chunks.
	@Test
	func redactsALogWhileCopyingIt() async throws {
		let directory = try TemporaryDirectory("DiagnosticsBundleTests")
		defer { directory.remove() }
		let source = directory.url.appending(path: "launcher.log")
		let line = "open /Users/tester/Library/x https://h.example/p?token=abc#top by tester\n"
		try Data(String(repeating: line, count: 5_000).utf8).write(to: source)

		let archive = try await DiagnosticsBundle.write(
			[.init(archivePath: "Logs/launcher.log", content: .redactedLog(source))],
			readme: "",
			named: baseName,
			to: directory.url.appending(path: "out"),
			redaction: redaction,
			reportCleanupFailure: { _ in }
		)

		let extracted = directory.url.appending(path: "extracted")
		try extract(archive, into: extracted)
		let copy = try String(
			contentsOf: extracted.appending(path: "Logs/launcher.log"), encoding: .utf8)
		let expected = "open ~/Library/x https://h.example/p#top by <user>\n"
		#expect(copy == String(repeating: expected, count: 5_000))
	}

	private func extract(_ archive: URL, into directory: URL) throws {
		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
		process.arguments = ["-x", "-k", archive.path, directory.path]
		try process.run()
		process.waitUntilExit()
		#expect(process.terminationStatus == 0)
	}
}
