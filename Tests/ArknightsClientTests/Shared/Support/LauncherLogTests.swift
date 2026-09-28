// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func launcherLogWritesShareableDiagnosticLines() async throws {
	let directory = FileManager.default.temporaryDirectory.appending(
		path: "LauncherLogTests.\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	let fileURL = directory.appending(path: "launcher.log")
	let log = LauncherLog(fileURL: fileURL)

	log.info("Installation started")
	log.error("Download failed\nConnection closed")
	await log.flush()

	let content = try String(contentsOf: fileURL, encoding: .utf8)
	#expect(content.contains("[INFO] Installation started"))
	#expect(content.contains("[ERROR] Download failed Connection closed"))
}

@Test
func launcherLogBoundsOversizedMessagesWithAnExplicitMarker() async throws {
	let directory = FileManager.default.temporaryDirectory.appending(
		path: "LauncherLogTests.\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	let fileURL = directory.appending(path: "launcher.log")
	let log = LauncherLog(fileURL: fileURL)
	let omittedSuffix = "END-OF-OVERSIZED-MESSAGE"
	let message =
		String(repeating: "a", count: AppConstants.Logging.maximumMessageBytes) + omittedSuffix

	log.info(message)
	await log.flush()

	let content = try String(contentsOf: fileURL, encoding: .utf8)
	#expect(content.contains(AppConstants.Logging.truncationMarker))
	#expect(content.contains(omittedSuffix) == false)
	#expect(content.lengthOfBytes(using: .utf8) <= AppConstants.Logging.maximumMessageBytes + 128)
}

@Test
func launcherLogRotatesBeforeAnAppendingEntryExceedsItsLimit() async throws {
	let directory = FileManager.default.temporaryDirectory.appending(
		path: "LauncherLogTests.\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
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
