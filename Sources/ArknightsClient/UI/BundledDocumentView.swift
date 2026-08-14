// SPDX-License-Identifier: MPL-2.0

import SwiftUI

enum BundledDocument: String, Identifiable {
	case changelog
	case projectLicense
	case thirdPartyNotices

	var id: String { rawValue }

	var title: String {
		switch self {
		case .changelog: "Changelog"
		case .projectLicense: "MPL-2.0 License"
		case .thirdPartyNotices: "Third-Party Notices"
		}
	}

	var resource: (name: String, extension: String?) {
		switch self {
		case .changelog: ("CHANGELOG", "md")
		case .projectLicense: ("LICENSE", nil)
		case .thirdPartyNotices: ("THIRD_PARTY_NOTICES", "md")
		}
	}

	var usesMarkdown: Bool {
		self != .projectLicense
	}

	func contents(bundle: Bundle = .main) -> String {
		let resource = resource
		guard let url = bundle.url(forResource: resource.name, withExtension: resource.extension),
			let contents = try? String(contentsOf: url, encoding: .utf8)
		else {
			return "This document is unavailable in the current build."
		}
		return contents
	}
}

struct BundledDocumentView: View {
	let document: BundledDocument
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			ScrollView {
				documentText
					.frame(maxWidth: .infinity, alignment: .leading)
					.textSelection(.enabled)
					.padding(28)
			}
			.navigationTitle(document.title)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") { dismiss() }
				}
			}
		}
		.frame(width: 720, height: 560)
	}

	@ViewBuilder
	private var documentText: some View {
		let contents = document.contents()
		if document.usesMarkdown {
			MarkdownDocument(source: contents)
		} else {
			Text(contents)
				.font(.system(size: 12, design: .monospaced))
				.lineSpacing(3)
		}
	}
}

private struct MarkdownDocument: View {
	let source: String

	var body: some View {
		LazyVStack(alignment: .leading, spacing: 5) {
			ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
				block(for: line)
			}
		}
	}

	private var lines: [String] {
		source.components(separatedBy: .newlines)
	}

	@ViewBuilder
	private func block(for line: String) -> some View {
		if line.isEmpty {
			Color.clear.frame(height: 5)
		} else if line == "---" {
			Divider().padding(.vertical, 5)
		} else if line.hasPrefix("### ") {
			Text(inline(String(line.dropFirst(4))))
				.font(.headline)
				.padding(.top, 8)
		} else if line.hasPrefix("## ") {
			Text(inline(String(line.dropFirst(3))))
				.font(.title2.bold())
				.padding(.top, 12)
		} else if line.hasPrefix("# ") {
			Text(inline(String(line.dropFirst(2))))
				.font(.title.bold())
		} else if line.hasPrefix("- ") {
			HStack(alignment: .firstTextBaseline, spacing: 9) {
				Text("•")
				Text(inline(String(line.dropFirst(2))))
			}
			.padding(.leading, 6)
		} else if isLinkDefinition(line) {
			EmptyView()
		} else {
			Text(inline(line))
				.font(.body)
				.lineSpacing(3)
		}
	}

	private func inline(_ source: String) -> AttributedString {
		let options = AttributedString.MarkdownParsingOptions(
			interpretedSyntax: .inlineOnlyPreservingWhitespace
		)
		return (try? AttributedString(markdown: source, options: options))
			?? AttributedString(source)
	}

	private func isLinkDefinition(_ line: String) -> Bool {
		guard line.first == "[", let closingBracket = line.firstIndex(of: "]") else {
			return false
		}
		return line[line.index(after: closingBracket)...].hasPrefix(": ")
	}
}
