// SPDX-License-Identifier: MPL-2.0

import Foundation

enum MarkdownBlock: Equatable {
	case heading(level: Int, source: String)
	case paragraph(String)
	case bullet(String)
	case table([[String]])
	case code(String)
	case divider
}

/// A small hand-rolled block parser (headings, paragraphs, bullets, tables, code, dividers)
/// for changelog and license text bundled with the app — not general-purpose Markdown.
struct MarkdownParser {
	let source: String

	var blocks: [MarkdownBlock] {
		let lines = contentLines
		var result: [MarkdownBlock] = []
		var index = 0

		while index < lines.count {
			let line = lines[index]
			if line.hasPrefix(">") {
				result.append(contentsOf: parseQuote(lines: lines, index: &index))
				continue
			}
			if line.trimmingCharacters(in: .whitespaces).isEmpty || isLinkDefinition(line) {
				index += 1
				continue
			}
			if line.hasPrefix("```") {
				let parsed = parseCode(lines: lines, start: index)
				result.append(.code(parsed.source))
				index = parsed.nextIndex
				continue
			}
			if index + 1 < lines.count, let level = setextHeadingLevel(lines[index + 1]) {
				result.append(.heading(level: level, source: line))
				index += 2
				continue
			}
			if index + 1 < lines.count, isTableDelimiter(lines[index + 1]) {
				let parsed = parseTable(lines: lines, start: index)
				result.append(.table(parsed.rows))
				index = parsed.nextIndex
				continue
			}
			if line == "---" {
				result.append(.divider)
				index += 1
				continue
			}
			if let heading = parseHeading(line) {
				result.append(heading)
				index += 1
				continue
			}
			if line.hasPrefix("- ") {
				result.append(.bullet(String(line.dropFirst(2))))
				index += 1
				continue
			}

			let paragraph = parseParagraph(lines: lines, start: index)
			result.append(.paragraph(paragraph.source))
			index = paragraph.nextIndex
		}
		return result
	}

	private func parseQuote(lines: [String], index: inout Int) -> [MarkdownBlock] {
		var quoted: [String] = []
		while index < lines.count, lines[index].hasPrefix(">") {
			var line = String(lines[index].dropFirst())
			if line.hasPrefix(" ") { line.removeFirst() }
			quoted.append(line)
			index += 1
		}
		if let marker = quoted.first,
			marker.hasPrefix("[!"), marker.hasSuffix("]")
		{
			let label = marker.dropFirst(2).dropLast().lowercased().capitalized
			quoted[0] = "**\(label)**"
			quoted.insert("", at: 1)
		}
		return MarkdownParser(source: quoted.joined(separator: "\n")).blocks
	}

	private var contentLines: [String] {
		let lines = source.components(separatedBy: .newlines)
		guard lines.first == "---",
			let closingDelimiter = lines.dropFirst().firstIndex(of: "---")
		else {
			return lines
		}
		return Array(lines[lines.index(after: closingDelimiter)...])
	}

	private func parseHeading(_ line: String) -> MarkdownBlock? {
		for level in 1...3 {
			let prefix = String(repeating: "#", count: level) + " "
			if line.hasPrefix(prefix) {
				return .heading(level: level, source: String(line.dropFirst(prefix.count)))
			}
		}
		return nil
	}

	private func parseTable(lines: [String], start: Int) -> (rows: [[String]], nextIndex: Int) {
		var rows = [tableCells(lines[start])]
		var index = start + 2
		while index < lines.count, lines[index].contains("|") {
			let cells = tableCells(lines[index])
			guard !cells.isEmpty else { break }
			rows.append(cells)
			index += 1
		}
		return (rows, index)
	}

	private func parseCode(lines: [String], start: Int) -> (source: String, nextIndex: Int) {
		var code: [String] = []
		var index = start + 1
		while index < lines.count, !lines[index].hasPrefix("```") {
			code.append(lines[index])
			index += 1
		}
		return (code.joined(separator: "\n"), min(index + 1, lines.count))
	}

	private func parseParagraph(lines: [String], start: Int) -> (source: String, nextIndex: Int) {
		var paragraph: [String] = []
		var index = start
		while index < lines.count {
			let line = lines[index]
			if line.trimmingCharacters(in: .whitespaces).isEmpty || isSpecialLine(line) {
				break
			}
			if index + 1 < lines.count,
				isTableDelimiter(lines[index + 1]) || setextHeadingLevel(lines[index + 1]) != nil
			{
				break
			}
			paragraph.append(line)
			index += 1
		}
		return (paragraph.joined(separator: "\n"), index)
	}

	private func isSpecialLine(_ line: String) -> Bool {
		line == "---" || line.hasPrefix("# ") || line.hasPrefix("## ")
			|| line.hasPrefix("### ") || line.hasPrefix("- ") || line.hasPrefix("```")
			|| line.hasPrefix(">")
			|| isLinkDefinition(line)
	}

	private func isTableDelimiter(_ line: String) -> Bool {
		guard line.contains("|") else { return false }
		let cells = tableCells(line)
		guard !cells.isEmpty else { return false }
		return cells.allSatisfy { cell in
			let value = cell.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
			return value.count >= 3 && value.allSatisfy { $0 == "-" }
		}
	}

	private func setextHeadingLevel(_ line: String) -> Int? {
		let value = line.trimmingCharacters(in: .whitespaces)
		guard value.count >= 3 else { return nil }
		if value.allSatisfy({ $0 == "=" }) { return 1 }
		if value.allSatisfy({ $0 == "-" }) { return 2 }
		return nil
	}

	private func tableCells(_ line: String) -> [String] {
		var value = line.trimmingCharacters(in: .whitespaces)
		if value.hasPrefix("|") { value.removeFirst() }
		if value.hasSuffix("|") { value.removeLast() }
		return value.split(separator: "|", omittingEmptySubsequences: false).map {
			$0.trimmingCharacters(in: .whitespaces)
		}
	}

	private func isLinkDefinition(_ line: String) -> Bool {
		guard line.first == "[", let closingBracket = line.firstIndex(of: "]") else {
			return false
		}
		return line[line.index(after: closingBracket)...].hasPrefix(": ")
	}
}
