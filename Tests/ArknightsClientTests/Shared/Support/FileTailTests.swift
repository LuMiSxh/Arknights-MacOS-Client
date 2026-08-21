// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func fileTailReturnsWholeFileWhenSmallerThanTheLimit() throws {
	let url = try makeTemporaryFile(contents: "line one\nline two\n")
	defer { try? FileManager.default.removeItem(at: url) }

	#expect(FileTail.read(of: url, maximumBytes: 1_024) == "line one\nline two")
}

@Test
func fileTailDropsAPossiblyTruncatedLeadingLine() throws {
	let lines = (1...50).map { "line \($0) of the log file" }
	let url = try makeTemporaryFile(contents: lines.joined(separator: "\n"))
	defer { try? FileManager.default.removeItem(at: url) }

	let tail = try #require(FileTail.read(of: url, maximumBytes: 40))

	#expect(tail == "line 50 of the log file")
}

private func makeTemporaryFile(contents: String) throws -> URL {
	let url = FileManager.default.temporaryDirectory
		.appendingPathComponent(UUID().uuidString)
	try contents.write(to: url, atomically: true, encoding: .utf8)
	return url
}
