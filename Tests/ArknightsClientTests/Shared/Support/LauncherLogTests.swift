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

	await log.info("Installation started")
	await log.error("Download failed\nConnection closed")

	let content = try String(contentsOf: fileURL, encoding: .utf8)
	#expect(content.contains("[INFO] Installation started"))
	#expect(content.contains("[ERROR] Download failed Connection closed"))
}
