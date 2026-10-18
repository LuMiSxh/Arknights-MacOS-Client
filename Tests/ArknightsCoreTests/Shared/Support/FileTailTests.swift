// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore

@Test
func fileTailNeverReadsBeyondTheRequestedByteLimit() throws {
	let temporary = try TemporaryDirectory("FileTailTests")
	defer { temporary.remove() }
	let small = temporary.url.appending(path: "small.log")
	try "line one\nline two\n".write(to: small, atomically: true, encoding: .utf8)
	let truncated = temporary.url.appending(path: "truncated.log")
	try (1...50).map { "line \($0) of the log file" }.joined(separator: "\n")
		.write(to: truncated, atomically: true, encoding: .utf8)
	let url = temporary.url.appending(path: "bytes.log")
	try "0123456789".write(to: url, atomically: true, encoding: .utf8)

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
