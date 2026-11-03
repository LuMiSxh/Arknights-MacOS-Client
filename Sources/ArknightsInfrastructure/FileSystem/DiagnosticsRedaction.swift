// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Removes the account's home path, user name, and URL query strings from log text.
///
/// This lowers accidental disclosure. It does not make a log safe to share unreviewed.
package struct DiagnosticsRedaction: Sendable {

	let homeDirectory: String
	let userName: String

	package init(homeDirectory: String, userName: String) {
		self.homeDirectory = homeDirectory
		self.userName = userName
	}

	func redact(_ text: String) -> String {
		var result = text
		if homeDirectory.count > 1 {
			result = result.replacing(homeDirectory, with: "~")
		}
		result = redactUserName(in: result)
		if result.contains("?") {
			// Built per call because `Regex` is not `Sendable`; callers pass chunks, not lines.
			let urlQuery = /(https?:\/\/[^\s?#"'<>]*)\?[^\s"'<>#]*/
			result = result.replacing(urlQuery) { String($0.output.1) }
		}
		return result
	}

	/// Replaces the user name only where it stands alone, so a short name inside a word stays intact.
	/// `/` is not a word character, so a path component such as `/Users/<name>` still counts.
	private func redactUserName(in text: String) -> String {
		guard !userName.isEmpty else { return text }
		var result = ""
		var cursor = text.startIndex
		for match in text.ranges(of: userName) {
			let precededByWord =
				match.lowerBound > text.startIndex
				&& text[text.index(before: match.lowerBound)].isWordCharacter
			let followedByWord =
				match.upperBound < text.endIndex
				&& text[match.upperBound].isWordCharacter
			result += text[cursor..<match.lowerBound]
			result += precededByWord || followedByWord ? userName : "<user>"
			cursor = match.upperBound
		}
		result += text[cursor...]
		return result
	}
}

extension Character {
	fileprivate var isWordCharacter: Bool { isLetter || isNumber || self == "_" }
}
