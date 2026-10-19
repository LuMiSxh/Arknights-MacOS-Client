// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore

@Test
func launcherLogWritesSanitizedAndBoundedDiagnosticLines() async throws {
	let temporary = try TemporaryDirectory("LauncherLogTests")
	defer { temporary.remove() }
	let directory = temporary.url
	let fileURL = directory.appending(path: "launcher.log")
	let log = LauncherLog(fileURL: fileURL)
	let omittedSuffix = "END-OF-OVERSIZED-MESSAGE"
	let oversizedMessage =
		String(repeating: "a", count: AppConstants.Logging.maximumMessageBytes) + omittedSuffix

	log.info("Installation started")
	log.error("Download failed\nConnection closed")
	log.info(oversizedMessage)
	await log.flush()

	let content = try String(contentsOf: fileURL, encoding: .utf8)
	#expect(content.split(separator: "\n").count == 3)
	#expect(content.contains(AppConstants.Logging.truncationMarker))
	#expect(content.contains(omittedSuffix) == false)
	let oversizedLine = try #require(content.split(separator: "\n").last)
	#expect(oversizedLine.utf8.count <= AppConstants.Logging.maximumMessageBytes + 128)
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

	let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
	let currentSize = try #require(attributes[.size] as? NSNumber)
	let previousURL = fileURL.deletingPathExtension()
		.appendingPathExtension("previous.log")
	#expect(currentSize.intValue <= 256)
	#expect(FileManager.default.fileExists(atPath: previousURL.path))
}
