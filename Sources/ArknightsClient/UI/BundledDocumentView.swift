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
				VStack(alignment: .leading, spacing: 16) {
					HStack(spacing: 8) {
						Rectangle().fill(SettingsVisuals.cyan).frame(width: 72, height: 3)
						Rectangle().fill(.secondary.opacity(0.28))
							.frame(height: 1)
							.frame(maxWidth: .infinity)
					}
					MarkdownDocument(source: document.contents())
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.textSelection(.enabled)
				.padding(28)
			}
			.background(.ultraThinMaterial)
			.navigationTitle(document.title)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") { dismiss() }
						.buttonStyle(.glassProminent)
				}
			}
		}
		.tint(SettingsVisuals.cyan)
		.frame(width: 760, height: 600)
	}
}

private struct MarkdownDocument: View {
	let source: String

	var body: some View {
		LazyVStack(alignment: .leading, spacing: 10) {
			ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
				MarkdownBlockView(block: block)
			}
		}
	}

	private var blocks: [MarkdownBlock] {
		MarkdownParser(source: source).blocks
	}
}

private struct MarkdownBlockView: View {
	let block: MarkdownBlock

	@ViewBuilder
	var body: some View {
		switch block {
		case .heading(let level, let source):
			Text(inline(source))
				.font(headingFont(level: level))
				.padding(.top, level == 1 ? 0 : 10)
		case .paragraph(let source):
			Text(inline(source))
				.font(.body)
				.lineSpacing(3)
		case .bullet(let source):
			HStack(alignment: .firstTextBaseline, spacing: 9) {
				Circle()
					.fill(SettingsVisuals.cyan)
					.frame(width: 5, height: 5)
				Text(inline(source))
			}
			.padding(.leading, 6)
		case .table(let rows):
			MarkdownTable(rows: rows)
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

	private func inline(_ source: String) -> AttributedString {
		let options = AttributedString.MarkdownParsingOptions(
			interpretedSyntax: .inlineOnlyPreservingWhitespace
		)
		return (try? AttributedString(markdown: source, options: options))
			?? AttributedString(source)
	}
}

private struct MarkdownTable: View {
	let rows: [[String]]

	var body: some View {
		ScrollView(.horizontal) {
			VStack(alignment: .leading, spacing: 0) {
				ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
					HStack(alignment: .top, spacing: 0) {
						ForEach(Array(row.enumerated()), id: \.offset) { columnIndex, cell in
							Text(inline(cell))
								.font(rowIndex == 0 ? .callout.bold() : .callout)
								.frame(
									width: columnWidth(columnIndex: columnIndex, count: row.count),
									alignment: .leading
								)
								.padding(10)
								.background(
									rowIndex == 0 ? SettingsVisuals.cyan.opacity(0.14) : .clear
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

	private func inline(_ source: String) -> AttributedString {
		let options = AttributedString.MarkdownParsingOptions(
			interpretedSyntax: .inlineOnlyPreservingWhitespace
		)
		return (try? AttributedString(markdown: source, options: options))
			?? AttributedString(source)
	}
}
