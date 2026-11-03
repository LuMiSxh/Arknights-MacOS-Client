// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
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

	var resource: BundledResource {
		switch self {
		case .changelog: .changelog
		case .projectLicense: .projectLicense
		case .thirdPartyNotices: .thirdPartyNotices
		}
	}

	func load(bundle: Bundle? = nil) throws -> String {
		try resource.text(in: bundle)
	}

	func loadAndParse(bundle: Bundle? = nil) async throws -> ParsedMarkdownDocument {
		try await Self.readAndParse(resource, bundle: bundle)
	}

	// Reading and parsing run on the concurrent executor, so the main actor only awaits the result.
	@concurrent
	private static func readAndParse(
		_ resource: BundledResource,
		bundle: Bundle?
	) async throws -> ParsedMarkdownDocument {
		ParsedMarkdownDocument(source: try resource.text(in: bundle))
	}
}

nonisolated struct ParsedMarkdownDocument: Sendable {
	let blocks: [MarkdownBlock]
	let tableColumnWidths: [[CGFloat]?]

	init(source: String) {
		self.init(blocks: MarkdownParser(source: source).blocks)
	}

	// Parsing is CPU work, so callers await it on the concurrent executor, off the main actor.
	@concurrent
	static func parse(source: String) async -> ParsedMarkdownDocument {
		ParsedMarkdownDocument(source: source)
	}

	init(blocks: [MarkdownBlock]) {
		self.blocks = blocks
		tableColumnWidths = blocks.map { block in
			guard case .table(let rows) = block else { return nil }
			return Self.widths(for: rows)
		}
	}

	private static func widths(for rows: [[String]]) -> [CGFloat] {
		let columnCount = rows.map(\.count).max() ?? 0
		return (0..<columnCount).map { columnIndex in
			let longestCell =
				rows
				.compactMap { row in row.indices.contains(columnIndex) ? row[columnIndex] : nil }
				.map(\.count)
				.max() ?? 0
			return min(max(CGFloat(longestCell) * 7.5 + 24, 112), 320)
		}
	}
}

private enum BundledDocumentLoadState {
	case loading
	case loaded(ParsedMarkdownDocument)
	case failed(BundledResourceError)
}

struct BundledDocumentView: View {
	let document: BundledDocument
	let accentColor: Color

	@State private var loadState = BundledDocumentLoadState.loading
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		ThemedModalView(
			title: document.title,

			width: 760,
			height: 600
		) {
			switch loadState {
			case .loading:
				ProgressView()
					.controlSize(.regular)
					.frame(maxWidth: .infinity, minHeight: 180)
					.accessibilityLabel(Text("Loading document"))
			case .loaded(let parsedDocument):
				MarkdownDocument(parsed: parsedDocument)
					.textSelection(.enabled)
			case .failed(let error):
				DocumentLoadErrorView(error: error)
			}
		} actions: {
			FloatingDoneButton {
				dismiss()
			}
		}
		.onExitCommand(perform: dismiss.callAsFunction)
		.launcherTheme(accent: accentColor)
		.task(id: document) {
			loadState = .loading
			do {
				let parsedDocument = try await document.loadAndParse()
				guard !Task.isCancelled else { return }
				loadState = .loaded(parsedDocument)
			} catch is CancellationError {
				return
			} catch let error as BundledResourceError {
				guard !Task.isCancelled else { return }
				loadState = .failed(error)
			} catch {
				guard !Task.isCancelled else { return }
				loadState = .failed(
					.unreadable(path: document.resource.path, reason: error.localizedDescription)
				)
			}
		}
	}
}

private struct DocumentLoadErrorView: View {
	let error: BundledResourceError

	var body: some View {
		ContentUnavailableView {
			Label(
				"Document unavailable",
				systemImage: "doc.badge.exclamationmark")
		} description: {
			Text("This document is unavailable in the current build.")
		}
		.frame(maxWidth: .infinity, minHeight: 180)
		.pointerStyle(.default)
	}
}

struct MarkdownDocument: View {
	@Environment(\.launcherTheme) private var theme
	private let initialDocument: ParsedMarkdownDocument?
	private let source: String?
	@State private var loadedDocument: ParsedMarkdownDocument?

	init(source: String) {
		initialDocument = nil
		self.source = source
	}

	init(parsed: ParsedMarkdownDocument) {
		initialDocument = parsed
		source = nil
	}

	var body: some View {
		Group {
			if let document = initialDocument ?? loadedDocument {
				LazyVStack(alignment: .leading, spacing: 12) {
					ForEach(document.blocks.indices, id: \.self) { index in
						MarkdownBlockView(
							block: document.blocks[index],
							columnWidths: document.tableColumnWidths[index] ?? []
						)
					}
				}
			} else {
				ProgressView()
					.controlSize(.regular)
					.frame(maxWidth: .infinity, minHeight: 80)
					.accessibilityLabel(Text("Loading document"))
			}
		}
		.tint(theme.accentInk)
		.pointerStyle(.default)
		.task(id: source) {
			guard let source else { return }
			loadedDocument = nil
			let document = await ParsedMarkdownDocument.parse(source: source)
			guard !Task.isCancelled else { return }
			loadedDocument = document
		}
	}
}

private struct MarkdownBlockView: View {
	@Environment(\.launcherTheme) private var theme
	let block: MarkdownBlock
	let columnWidths: [CGFloat]

	@ViewBuilder
	var body: some View {
		switch block {
		case .heading(let level, let source):
			Text(markdownInline(source))
				.font(headingFont(level: level))
				.padding(.top, level == 1 ? 0 : 12)
				.accessibilityHeading(level == 1 ? .h1 : level == 2 ? .h2 : .h3)
		case .paragraph(let source):
			Text(markdownInline(source))
				.font(.body)
				.lineSpacing(4)
		case .bullet(let source):
			HStack(alignment: .firstTextBaseline, spacing: 8) {
				Circle()
					.fill(theme.accentFill)
					.frame(width: 4, height: 4)
				Text(markdownInline(source))
			}
			.padding(.leading, 8)
		case .numbered(let number, let source):
			HStack(alignment: .firstTextBaseline, spacing: 8) {
				Text("\(number).")
					.foregroundStyle(theme.accentInk)
					.monospacedDigit()
				Text(markdownInline(source))
			}
			.padding(.leading, 8)
		case .table(let rows):
			MarkdownTable(rows: rows, columnWidths: columnWidths)
				.padding(.vertical, 4)
		case .code(let source):
			Text(source)
				.font(.system(.callout, design: .monospaced))
				.padding(12)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(
					theme.controlFill, in: .rect(cornerRadius: LauncherVisuals.Radius.control))
		case .divider:
			Divider().padding(.vertical, 4)
		}
	}

	private func headingFont(level: Int) -> Font {
		switch level {
		case 1: .title.weight(.medium)
		case 2: .title2.weight(.medium)
		default: .headline
		}
	}
}

private struct MarkdownTable: View {
	@Environment(\.launcherTheme) private var theme
	let rows: [[String]]
	let columnWidths: [CGFloat]

	var body: some View {
		ScrollView(.horizontal) {
			VStack(alignment: .leading, spacing: 0) {
				ForEach(Array(rows.enumerated()), id: \.offset) { entry in
					HStack(alignment: .top, spacing: 0) {
						ForEach(entry.element.indices, id: \.self) { columnIndex in
							MarkdownTableCell(
								source: entry.element[columnIndex],
								width: columnWidths[columnIndex],
								isHeader: entry.offset == 0
							)
						}
					}
					.overlay(alignment: .bottom) { SettingsHairline() }
				}
			}
			.overlay {
				RoundedRectangle(cornerRadius: LauncherVisuals.Radius.control)
					.stroke(theme.hairline, lineWidth: 1)
			}
			.clipShape(.rect(cornerRadius: LauncherVisuals.Radius.control))
		}
		.scrollIndicators(.visible)
	}

}

private struct MarkdownTableCell: View {
	@Environment(\.launcherTheme) private var theme
	let source: String
	let width: CGFloat
	let isHeader: Bool

	private var font: Font {
		isHeader ? .callout.weight(.medium) : .callout
	}

	private var fill: Color {
		guard isHeader else { return Color.clear }
		return theme.controlFill
	}

	var body: some View {
		Text(markdownInline(source))
			.font(font)
			.frame(width: width, alignment: .leading)
			.padding(8)
			.background(fill)
			.overlay(alignment: .trailing) { Divider() }
	}
}

private func markdownInline(_ source: String) -> AttributedString {
	let options = AttributedString.MarkdownParsingOptions(
		interpretedSyntax: .inlineOnlyPreservingWhitespace
	)
	do {
		return try AttributedString(markdown: source, options: options)
	} catch {
		return AttributedString(source)
	}
}
