// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore

struct DiagnosticsArchiveTests {
	@Test(arguments: [GamePublisher.hypergryph, .gryphline, .yostar])
	func sdkLogItemsListSortedRegularFilesOnly(publisher: GamePublisher) throws {
		let temporary = try TemporaryDirectory("DiagnosticsArchiveTests")
		defer { temporary.remove() }
		let directory = temporary.url.appending(path: "sdklogs", directoryHint: .isDirectory)
		let outside = temporary.url.appending(path: "outside.log")
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		try Data("outside".utf8).write(to: outside)
		try Data("web".utf8).write(to: directory.appending(path: "HGWebview.log"))
		try Data("sdk".utf8).write(to: directory.appending(path: "u8sdk_pc.log"))
		try FileManager.default.createSymbolicLink(
			at: directory.appending(path: "link.log"), withDestinationURL: outside)
		try FileManager.default.createDirectory(
			at: directory.appending(path: "nested", directoryHint: .isDirectory),
			withIntermediateDirectories: true)

		let items = try DiagnosticsArchive.sdkLogItems(in: directory, publisher: publisher)

		#expect(
			items.map(\.archivePath) == [
				"Logs/sdklogs/\(publisher.rawValue)/HGWebview.log",
				"Logs/sdklogs/\(publisher.rawValue)/u8sdk_pc.log",
			])
		let missing = temporary.url.appending(path: "missing", directoryHint: .isDirectory)
		#expect(try DiagnosticsArchive.sdkLogItems(in: missing, publisher: publisher).isEmpty)
	}
}
