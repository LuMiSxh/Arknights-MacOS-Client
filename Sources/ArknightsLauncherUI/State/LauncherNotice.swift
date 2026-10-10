// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation

struct LauncherNotice: Identifiable {
	let id = UUID()
	let content: AttributedString
}

enum LauncherNoticeFormatter {
	static func notice(fromHTML html: String) -> LauncherNotice? {
		let trimmedHTML = html.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedHTML.isEmpty, trimmedHTML.utf8.count <= 128 * 1_024 else { return nil }

		guard
			let data = withoutRemoteResources(trimmedHTML).data(using: .utf8),
			let rendered = try? NSMutableAttributedString(
				data: data,
				options: [
					.documentType: NSAttributedString.DocumentType.html,
					.characterEncoding: String.Encoding.utf8.rawValue,
				],
				documentAttributes: nil
			)
		else {
			return nil
		}

		let fullRange = NSRange(location: 0, length: rendered.length)
		rendered.removeAttribute(.attachment, range: fullRange)
		rendered.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
		rendered.enumerateAttribute(.font, in: fullRange) { value, range, _ in
			let font = value as? NSFont
			let weight: NSFont.Weight =
				font?.fontDescriptor.symbolicTraits.contains(.bold) == true ? .semibold : .regular
			rendered.addAttribute(
				.font,
				value: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: weight),
				range: range
			)
		}

		return LauncherNotice(content: AttributedString(rendered))
	}

	/// Drops elements and CSS URLs that make the HTML importer fetch remote resources.
	/// Images are discarded after import anyway, so they are never worth a network request.
	static func withoutRemoteResources(_ html: String) -> String {
		let blockElements = #"(?is)<(script|style|iframe|object|video|audio)\b.*?</\1\s*>"#
		let voidElements = #"(?i)<(img|link|meta|embed|source|base|input)\b[^>]*>"#
		let cssURLs = #"(?i)url\s*\([^)]*\)"#
		return [blockElements, voidElements, cssURLs].reduce(html) { result, pattern in
			result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
		}
	}
}
