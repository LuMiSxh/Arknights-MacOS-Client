// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCore

@Test
func fileTailNeverReadsBeyondTheRequestedByteLimit() throws {
	let small = try makeTemporaryFile(contents: "line one\nline two\n")
	let lines = (1...50).map { "line \($0) of the log file" }
	let truncated = try makeTemporaryFile(contents: lines.joined(separator: "\n"))
	let url = try makeTemporaryFile(contents: "0123456789")
	defer {
		for file in [small, truncated, url] { try? FileManager.default.removeItem(at: file) }
	}

	#expect(FileTail.read(of: small, maximumBytes: 1_024) == "line one\nline two")
	#expect(FileTail.read(of: truncated, maximumBytes: 40) == "line 50 of the log file")
	#expect(FileTail.read(of: url, maximumBytes: 0) == nil)

	let handle = try FileHandle(forReadingFrom: url)
	defer { handle.closeFile() }
	let size = try handle.seekToEnd()
	let offset = size - 4
	try handle.seek(toOffset: offset)
	let writer = try FileHandle(forWritingTo: url)
	try writer.seekToEnd()
	try writer.write(contentsOf: Data("appended after seek".utf8))
	try writer.close()

	#expect(try FileTail.readTail(from: handle, offset: offset, maximumBytes: 4) == "6789")
}

private func makeTemporaryFile(contents: String) throws -> URL {
	let url = FileManager.default.temporaryDirectory
		.appendingPathComponent(UUID().uuidString)
	try contents.write(to: url, atomically: true, encoding: .utf8)
	return url
}
