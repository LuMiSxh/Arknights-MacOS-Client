// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Groups structured log entries by the part of the launcher that emits them.
package enum LogCategory: String, Sendable {
	case app
	case refresh
	case install
	case runtime
	case prefix
	case launch
	case session
	case music
	case presence
	case customization
	case update
	case diagnostics
	case settings
	case storage
}

/// A value rendered into a structured log line as `key=value`.
package protocol LogValue {
	var logValue: String { get }
}

/// Enums with a string raw value opt in by declaring `: LogValue`.
extension LogValue where Self: RawRepresentable, RawValue == String {
	package var logValue: String { rawValue }
}

extension Optional: LogValue where Wrapped: LogValue {
	package var logValue: String { self?.logValue ?? "none" }
}

extension String: LogValue {
	package var logValue: String { self }
}

extension Int: LogValue {
	package var logValue: String { String(self) }
}

extension Int32: LogValue {
	package var logValue: String { String(self) }
}

extension Int64: LogValue {
	package var logValue: String { String(self) }
}

extension Bool: LogValue {
	package var logValue: String { self ? "true" : "false" }
}

extension Double: LogValue {
	package var logValue: String {
		guard self != 0 else { return "0" }
		var text = String(
			format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), self)
		while text.hasSuffix("0") { text.removeLast() }
		if text.hasSuffix(".") { text.removeLast() }
		return text
	}
}

extension UUID: LogValue {
	package var logValue: String { uuidString }
}

extension Duration: LogValue {
	package var logValue: String {
		let components = self.components
		let seconds =
			Double(components.seconds)
			+ Double(components.attoseconds) / 1_000_000_000_000_000_000
		return String(
			format: "%.2fs", locale: Locale(identifier: "en_US_POSIX"), seconds)
	}
}

/// File URLs log their path; other URLs log scheme, host, and path without the query.
extension URL: LogValue {
	package var logValue: String {
		if isFileURL { return path }
		var text = ""
		if let scheme { text += "\(scheme)://" }
		if let host { text += host }
		text += path
		return text
	}
}

/// Sorted so a set renders the same way on every run.
extension Set: LogValue where Element: LogValue {
	package var logValue: String {
		map(\.logValue).sorted().joined(separator: ",")
	}
}

/// Ordered key/value pairs attached to one structured log entry.
package struct LogFields: ExpressibleByDictionaryLiteral {
	package typealias Key = StaticString
	package typealias Value = any LogValue

	private let entries: [(key: StaticString, value: String)]

	package init(dictionaryLiteral elements: (StaticString, any LogValue)...) {
		entries = elements.map { (key: $0.0, value: $0.1.logValue) }
	}

	/// Space-prefixed `key=value` pairs in literal order, ready to append to a line.
	var rendered: String {
		entries.map { " \(keyText($0.key))=\(logFieldValue($0.value))" }.joined()
	}
}

/// Renders one field value bare when it stays unambiguous, otherwise double-quoted.
package func logFieldValue(_ value: String) -> String {
	guard !value.isEmpty else { return "\"\"" }
	let needsQuotes = value.unicodeScalars.contains { scalar in
		scalar == " " || scalar == "\"" || scalar == "=" || scalar == "\\"
			|| scalar.properties.generalCategory == .control
	}
	guard needsQuotes else { return value }
	let escaped =
		value
		.replacingOccurrences(of: "\\", with: "\\\\")
		.replacingOccurrences(of: "\"", with: "\\\"")
	return "\"\(escaped)\""
}

private func keyText(_ key: StaticString) -> String {
	String(describing: key)
}
