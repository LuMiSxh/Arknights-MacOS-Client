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
		if !userName.isEmpty {
			result = result.replacing(userName, with: "<user>")
		}
		if result.contains("?") {
			// Built per call because `Regex` is not `Sendable`; callers pass chunks, not lines.
			let urlQuery = /(https?:\/\/[^\s?#"'<>]*)\?[^\s"'<>#]*/
			result = result.replacing(urlQuery) { String($0.output.1) }
		}
		return result
	}
}
