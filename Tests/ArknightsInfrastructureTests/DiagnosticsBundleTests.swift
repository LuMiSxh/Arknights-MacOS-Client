// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsInfrastructure

struct DiagnosticsBundleTests {
	private let baseName = "DiagnosticsBundleTests"

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
			to: output
		)

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

	/// A path that leaves the staging folder is rejected, and nothing is written.
	@Test
	func rejectsAnItemOutsideTheArchive() async throws {
		let directory = try TemporaryDirectory("DiagnosticsBundleTests")
		defer { directory.remove() }

		await #expect(throws: DiagnosticsBundleError.self) {
			try await DiagnosticsBundle.write(
				[.init(archivePath: "../escape.txt", content: .text("x"))],
				readme: "",
				named: baseName,
				to: directory.url
			)
		}
		#expect(
			!FileManager.default.fileExists(
				atPath: directory.url.appending(path: "escape.txt").path))
	}

	/// A file item that does not exist fails the write instead of producing a partial archive.
	@Test
	func failsWhenAFileItemIsMissing() async throws {
		let directory = try TemporaryDirectory("DiagnosticsBundleTests")
		defer { directory.remove() }

		await #expect(throws: DiagnosticsBundleError.self) {
			try await DiagnosticsBundle.write(
				[
					.init(
						archivePath: "Logs/missing.log",
						content: .file(directory.url.appending(path: "missing.log")))
				],
				readme: "",
				named: baseName,
				to: directory.url
			)
		}
		#expect(
			!FileManager.default.fileExists(
				atPath: directory.url.appending(path: "\(baseName).zip").path))
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
