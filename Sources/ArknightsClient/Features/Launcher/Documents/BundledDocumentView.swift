// SPDX-License-Identifier: MPL-2.0

import SwiftUI

enum BundledDocument: String, Identifiable {
	case changelog
	case projectLicense
	case thirdPartyNotices

	enum LoadError: Error, Equatable, LocalizedError {
		case missingResource(name: String, fileExtension: String?)
		case unreadableResource(name: String, reason: String)

		var errorDescription: String? {
			LauncherStrings.documentUnavailable
		}
	}

	var id: String { rawValue }

	var title: String {
		switch self {
		case .changelog: LauncherStrings.documentChangelog
		case .projectLicense: LauncherStrings.documentLicense
		case .thirdPartyNotices: LauncherStrings.documentNotices
		}
	}

	var resource: (name: String, extension: String?) {
		switch self {
		case .changelog: ("CHANGELOG", "md")
		case .projectLicense: ("LICENSE", nil)
		case .thirdPartyNotices: ("THIRD_PARTY_NOTICES", "md")
		}
	}

	func load(bundle: Bundle = .main) throws -> String {
		let url = try resourceURL(bundle: bundle)
		do {
			return try String(contentsOf: url, encoding: .utf8)
		} catch {
			throw LoadError.unreadableResource(
				name: resource.name,
				reason: error.localizedDescription
			)
		}
	}

	func loadAndParse(bundle: Bundle = .main) async throws -> ParsedMarkdownDocument {
		let url = try resourceURL(bundle: bundle)
		do {
			return try await Task.detached(priority: .utility) {
				let source = try String(contentsOf: url, encoding: .utf8)
				return ParsedMarkdownDocument(source: source)
			}.value
		} catch is CancellationError {
			throw CancellationError()
		} catch {
			throw LoadError.unreadableResource(
				name: resource.name,
				reason: error.localizedDescription
			)
		}
	}

	private func resourceURL(bundle: Bundle) throws -> URL {
		let resource = resource
		guard let url = bundle.url(forResource: resource.name, withExtension: resource.extension)
		else {
			throw LoadError.missingResource(
				name: resource.name,
				fileExtension: resource.extension
			)
		}
		return url
	}
}

struct ParsedMarkdownDocument: Sendable {
	let blocks: [MarkdownBlock]
	let tableColumnWidths: [[CGFloat]?]

	init(source: String) {
		self.init(blocks: MarkdownParser(source: source).blocks)
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
	case failed(BundledDocument.LoadError)
}

struct BundledDocumentView: View {
	let document: BundledDocument
	let accentColor: Color
	let hudTintColor: Color
	@State private var loadState = BundledDocumentLoadState.loading
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		ThemedModalView(
			title: document.title,
			hudTintColor: hudTintColor,
			width: 760,
			height: 600
		) {
			switch loadState {
			case .loading:
				ProgressView()
					.controlSize(.large)
					.frame(maxWidth: .infinity, minHeight: 180)
					.accessibilityLabel(Text(LauncherStrings.documentLoading))
			case .loaded(let parsedDocument):
				MarkdownDocument(parsed: parsedDocument, accentColor: accentColor)
					.textSelection(.enabled)
			case .failed(let error):
				DocumentLoadErrorView(error: error)
			}
		} actions: {
			FloatingDoneButton(accentColor: accentColor) {
				dismiss()
			}
		}
		.onExitCommand(perform: dismiss.callAsFunction)
		.task(id: document) {
			loadState = .loading
			do {
				let parsedDocument = try await document.loadAndParse()
				guard !Task.isCancelled else { return }
				loadState = .loaded(parsedDocument)
			} catch is CancellationError {
				return
			} catch let error as BundledDocument.LoadError {
				guard !Task.isCancelled else { return }
				loadState = .failed(error)
			} catch {
				guard !Task.isCancelled else { return }
				loadState = .failed(
					.unreadableResource(
						name: document.resource.name, reason: error.localizedDescription)
				)
			}
		}
	}
}

private struct DocumentLoadErrorView: View {
	let error: BundledDocument.LoadError

	var body: some View {
		ContentUnavailableView {
			Label(LauncherStrings.documentUnavailable, systemImage: "doc.badge.exclamationmark")
		} description: {
			Text(error.localizedDescription)
		}
		.frame(maxWidth: .infinity, minHeight: 180)
		.pointerStyle(.default)
	}
}

struct MarkdownDocument: View {
	let accentColor: Color
	private let initialDocument: ParsedMarkdownDocument?
	private let source: String?
	@State private var loadedDocument: ParsedMarkdownDocument?

	init(source: String, accentColor: Color) {
		self.accentColor = accentColor
		initialDocument = nil
		self.source = source
	}

	init(parsed: ParsedMarkdownDocument, accentColor: Color) {
		self.accentColor = accentColor
		initialDocument = parsed
		source = nil
	}

	var body: some View {
		Group {
			if let document = initialDocument ?? loadedDocument {
				LazyVStack(alignment: .leading, spacing: 10) {
					ForEach(document.blocks.indices, id: \.self) { index in
						MarkdownBlockView(
							block: document.blocks[index],
							accentColor: accentColor,
							columnWidths: document.tableColumnWidths[index] ?? []
						)
					}
				}
			} else {
				ProgressView()
					.controlSize(.small)
					.frame(maxWidth: .infinity, minHeight: 80)
					.accessibilityLabel(Text(LauncherStrings.documentLoading))
			}
		}
		.tint(accentColor)
		.pointerStyle(.default)
		.task(id: source) {
			guard let source else { return }
			loadedDocument = nil
			let document = await Task.detached(priority: .utility) {
				ParsedMarkdownDocument(source: source)
			}.value
			guard !Task.isCancelled else { return }
			loadedDocument = document
		}
	}
}

private struct MarkdownBlockView: View {
	let block: MarkdownBlock
	let accentColor: Color
	let columnWidths: [CGFloat]

	@ViewBuilder
	var body: some View {
		switch block {
		case .heading(let level, let source):
			Text(markdownInline(source))
				.font(headingFont(level: level))
				.padding(.top, level == 1 ? 0 : 10)
				.accessibilityHeading(level == 1 ? .h1 : level == 2 ? .h2 : .h3)
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
		case .numbered(let number, let source):
			HStack(alignment: .firstTextBaseline, spacing: 9) {
				Text("\(number).")
					.foregroundStyle(accentColor)
					.monospacedDigit()
				Text(markdownInline(source))
			}
			.padding(.leading, 6)
		case .table(let rows):
			MarkdownTable(rows: rows, accentColor: accentColor, columnWidths: columnWidths)
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
	let columnWidths: [CGFloat]

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
									width: columnWidths[columnIndex],
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
