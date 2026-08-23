// SPDX-License-Identifier: MPL-2.0

import SwiftUI

enum BundledDocument: String, Identifiable {
	case changelog
	case projectLicense
	case thirdPartyNotices

	var id: String { rawValue }

	var title: String {
		switch self {
		case .changelog: L10n.string(LauncherStrings.documentChangelog)
		case .projectLicense: L10n.string(LauncherStrings.documentLicense)
		case .thirdPartyNotices: L10n.string(LauncherStrings.documentNotices)
		}
	}

	var resource: (name: String, extension: String?) {
		switch self {
		case .changelog: ("CHANGELOG", "md")
		case .projectLicense: ("LICENSE", nil)
		case .thirdPartyNotices: ("THIRD_PARTY_NOTICES", "md")
		}
	}

	func contents(bundle: Bundle = .main) -> String {
		let resource = resource
		guard let url = bundle.url(forResource: resource.name, withExtension: resource.extension),
			let contents = try? String(contentsOf: url, encoding: .utf8)
		else {
			return L10n.string(LauncherStrings.documentUnavailable)
		}
		return contents
	}
}

struct BundledDocumentView: View {
	let document: BundledDocument
	let accentColor: Color
	let hudTintColor: Color
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		ThemedModalView(
			title: document.title,
			accentColor: accentColor,
			hudTintColor: hudTintColor,
			width: 760,
			height: 600
		) {
			MarkdownDocument(source: document.contents(), accentColor: accentColor)
				.textSelection(.enabled)
		} actions: {
			FloatingDoneButton(accentColor: accentColor) {
				dismiss()
			}
		}
	}
}

struct MarkdownDocument: View {
	let accentColor: Color
	private let blocks: [MarkdownBlock]

	init(source: String, accentColor: Color) {
		self.accentColor = accentColor
		blocks = MarkdownParser(source: source).blocks
	}

	var body: some View {
		LazyVStack(alignment: .leading, spacing: 10) {
			ForEach(blocks.indices, id: \.self) { index in
				MarkdownBlockView(block: blocks[index], accentColor: accentColor)
			}
		}
	}
}

private struct MarkdownBlockView: View {
	let block: MarkdownBlock
	let accentColor: Color

	@ViewBuilder
	var body: some View {
		switch block {
		case .heading(let level, let source):
			Text(markdownInline(source))
				.font(headingFont(level: level))
				.padding(.top, level == 1 ? 0 : 10)
		case .paragraph(let source):
			Text(markdownInline(source))
				.font(.body)
				.lineSpacing(3)
		case .bullet(let source):
			HStack(alignment: .firstTextBaseline, spacing: 9) {
				Circle()
					.fill(accentColor)
					.frame(width: 5, height: 5)
				Text(markdownInline(source))
			}
			.padding(.leading, 6)
		case .table(let rows):
			MarkdownTable(rows: rows, accentColor: accentColor)
				.padding(.vertical, 4)
		case .code(let source):
			Text(source)
				.font(.system(.callout, design: .monospaced))
				.padding(12)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(.black.opacity(0.18), in: .rect(cornerRadius: 8))
		case .divider:
			Divider().padding(.vertical, 5)
		}
	}

	private func headingFont(level: Int) -> Font {
		switch level {
		case 1: .title.bold()
		case 2: .title2.bold()
		default: .headline
		}
	}
}

private struct MarkdownTable: View {
	let rows: [[String]]
	let accentColor: Color

	var body: some View {
		ScrollView(.horizontal) {
			VStack(alignment: .leading, spacing: 0) {
				ForEach(rows.indices, id: \.self) { rowIndex in
					let row = rows[rowIndex]
					HStack(alignment: .top, spacing: 0) {
						ForEach(row.indices, id: \.self) { columnIndex in
							Text(markdownInline(row[columnIndex]))
								.font(rowIndex == 0 ? .callout.bold() : .callout)
								.frame(
									width: columnWidth(columnIndex: columnIndex, count: row.count),
									alignment: .leading
								)
								.padding(10)
								.background(
									rowIndex == 0 ? accentColor.opacity(0.14) : .clear
								)
								.overlay(alignment: .trailing) { Divider() }
						}
					}
					.overlay(alignment: .bottom) { Divider() }
				}
			}
			.overlay {
				RoundedRectangle(cornerRadius: 9)
					.stroke(.secondary.opacity(0.28), lineWidth: 1)
			}
			.clipShape(.rect(cornerRadius: 9))
		}
		.scrollIndicators(.visible)
	}

	private func columnWidth(columnIndex: Int, count: Int) -> CGFloat {
		if count == 4 {
			return [150, 250, 290, 230][columnIndex]
		}
		return max(160, 680 / CGFloat(max(count, 1)))
	}
}

private func markdownInline(_ source: String) -> AttributedString {
	let options = AttributedString.MarkdownParsingOptions(
		interpretedSyntax: .inlineOnlyPreservingWhitespace
	)
	return (try? AttributedString(markdown: source, options: options))
		?? AttributedString(source)
}
