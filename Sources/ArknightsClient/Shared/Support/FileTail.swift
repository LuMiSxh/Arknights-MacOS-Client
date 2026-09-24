// SPDX-License-Identifier: MPL-2.0

import Foundation

enum FileTail {
	/// Reads at most `maximumBytes` from the end of `url`, dropping a possibly
	/// truncated leading line so the excerpt starts cleanly.
	static func read(of url: URL, maximumBytes: Int) -> String? {
		guard maximumBytes > 0 else { return nil }

		do {
			let handle = try FileHandle(forReadingFrom: url)
			defer { handle.closeFile() }
			let size = try handle.seekToEnd()
			let offset = size > UInt64(maximumBytes) ? size - UInt64(maximumBytes) : 0
			try handle.seek(toOffset: offset)
			return try readTail(from: handle, offset: offset, maximumBytes: maximumBytes)
		} catch {
			return nil
		}
	}

	static func readTail(
		from handle: FileHandle,
		offset: UInt64,
		maximumBytes: Int
	) throws -> String? {
		guard maximumBytes > 0,
			let data = try handle.read(upToCount: maximumBytes),
			var text = String(data: data, encoding: .utf8)
		else { return nil }
		if offset > 0, let newline = text.firstIndex(of: "\n") {
			text = String(text[text.index(after: newline)...])
		}
		return text.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}
