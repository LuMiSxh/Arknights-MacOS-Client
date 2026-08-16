// SPDX-License-Identifier: MPL-2.0

import Foundation

enum FileTail {
	/// Reads at most `maximumBytes` from the end of `url`, dropping a possibly
	/// truncated leading line so the excerpt starts cleanly.
	static func read(of url: URL, maximumBytes: Int) -> String? {
		guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
		defer { try? handle.close() }
		guard let size = try? handle.seekToEnd() else { return nil }
		let offset = size > UInt64(maximumBytes) ? size - UInt64(maximumBytes) : 0
		guard (try? handle.seek(toOffset: offset)) != nil,
			let data = try? handle.readToEnd(),
			var text = String(data: data, encoding: .utf8)
		else { return nil }
		if offset > 0, let newline = text.firstIndex(of: "\n") {
			text = String(text[text.index(after: newline)...])
		}
		return text.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}
