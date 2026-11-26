// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Reads presented failures out of the launcher log text.
///
/// The launcher writes `<ISO8601> ERROR app failure-presented code=… operation=… detail="…"`.
/// Parsing the text keeps one definition of that line for the diagnostics summary.
package enum LogFailureParser {
	/// The failures in `text`, oldest first, capped at `limit`. A malformed line is skipped.
	package static func failures(
		inLogText text: String, limit: Int = 5
	) -> [DiagnosticsEnvironment.Failure] {
		let failures = text.split(whereSeparator: \.isNewline).compactMap { failure(in: $0) }
		return Array(failures.suffix(limit))
	}

	private static func failure(in line: Substring) -> DiagnosticsEnvironment.Failure? {
		guard let timestampEnd = line.firstIndex(of: " ") else { return nil }
		let time = String(line[..<timestampEnd])
		let rest = line[line.index(after: timestampEnd)...]
		let eventPrefix = "ERROR app failure-presented"
		guard rest.hasPrefix(eventPrefix) else { return nil }
		let afterEvent = rest.dropFirst(eventPrefix.count)
		guard afterEvent.first == " " else { return nil }
		let fields = fields(in: afterEvent.dropFirst())
		guard let code = fields["code"], let operation = fields["operation"] else { return nil }
		return DiagnosticsEnvironment.Failure(time: time, code: code, operation: operation)
	}

	/// Splits `key=value` tokens, honouring the `\"` and `\\` escapes of a quoted value.
	private static func fields(in text: Substring) -> [String: String] {
		var fields: [String: String] = [:]
		var index = text.startIndex
		while index < text.endIndex {
			while index < text.endIndex, text[index] == " " {
				index = text.index(after: index)
			}
			guard index < text.endIndex else { break }
			let keyStart = index
			while index < text.endIndex, text[index] != "=", text[index] != " " {
				index = text.index(after: index)
			}
			guard index < text.endIndex, text[index] == "=" else { continue }
			let key = String(text[keyStart..<index])
			index = text.index(after: index)
			fields[key] = value(in: text, at: &index)
		}
		return fields
	}

	private static func value(in text: Substring, at index: inout String.Index) -> String {
		var value = ""
		guard index < text.endIndex else { return value }
		if text[index] == "\"" {
			index = text.index(after: index)
			while index < text.endIndex {
				let character = text[index]
				index = text.index(after: index)
				if character == "\"" { break }
				if character == "\\", index < text.endIndex {
					value.append(text[index])
					index = text.index(after: index)
				} else {
					value.append(character)
				}
			}
			return value
		}
		while index < text.endIndex, text[index] != " " {
			value.append(text[index])
			index = text.index(after: index)
		}
		return value
	}
}
