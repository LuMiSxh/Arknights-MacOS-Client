// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore

@Test(
	arguments: [
		("line feed", "Download failed\n[ERROR] injected"),
		("carriage return", "Download failed\r[ERROR] injected"),
		("escape", "Download failed\u{1B}[2K[ERROR] injected"),
		("NUL", "Download failed\0[ERROR] injected"),
	]
)
func launcherLogFlattensControlCharactersSoEntriesCannotInjectLines(
	_ label: String,
	_ message: String
) async throws {
	let temporary = try TemporaryDirectory("LauncherLogTests")
	defer { temporary.remove() }
	let fileURL = temporary.url.appending(path: "launcher.log")
	let log = LauncherLog(fileURL: fileURL)

	log.info(message)
	await log.flush()

	let content = try String(contentsOf: fileURL, encoding: .utf8)
	let lines = content.components(separatedBy: "\n")
	#expect(lines.count == 2)
	let entry = try #require(lines.first)
	#expect(entry.contains("injected"))
	#expect(entry.unicodeScalars.allSatisfy { $0.properties.generalCategory != .control })
}

@Test
func launcherLogRotatesBeforeAnAppendingEntryExceedsItsLimit() async throws {
	let temporary = try TemporaryDirectory("LauncherLogTests")
	defer { temporary.remove() }
	let directory = temporary.url
	let fileURL = directory.appending(path: "launcher.log")
	let log = LauncherLog(
		fileURL: fileURL,
		maximumFileSize: 256,
		maximumMessageBytes: 64
	)

	log.info(String(repeating: "a", count: 64))
	log.info(String(repeating: "b", count: 64))
	log.info(String(repeating: "c", count: 64))
	await log.flush()

	let previousURL = fileURL.deletingPathExtension()
		.appendingPathExtension("previous.log")
	#expect(FileManager.default.fileExists(atPath: previousURL.path))
}

@Test
func launcherLogRecreatesTheFileAfterItIsDeleted() async throws {
	let temporary = try TemporaryDirectory("LauncherLogTests")
	defer { temporary.remove() }
	let fileURL = temporary.url.appending(path: "launcher.log")
	let log = LauncherLog(fileURL: fileURL)

	log.info("before")
	await log.flush()
	try FileManager.default.removeItem(at: fileURL)
	log.info("after")
	await log.flush()

	let content = try String(contentsOf: fileURL, encoding: .utf8)
	#expect(content.components(separatedBy: "\n").count == 2)
}
