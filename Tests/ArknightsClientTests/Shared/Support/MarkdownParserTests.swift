// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsClient

struct MarkdownParserSyntaxCase: Sendable {
	let label: String
	let source: String
	let expected: [MarkdownBlock]
}

private let markdownParserSyntaxCases = [
	MarkdownParserSyntaxCase(
		label: "tables with inline source",
		source: """
			# Components

			| Name | Version | Source |
			| --- | ---: | --- |
			| Wine | `11.15` | [Repository](https://example.com) |

			- Bundled with the launcher
			""",
		expected: [
			.heading(level: 1, source: "Components"),
			.table([
				["Name", "Version", "Source"],
				["Wine", "`11.15`", "[Repository](https://example.com)"],
			]),
			.bullet("Bundled with the launcher"),
		]
	),
	MarkdownParserSyntaxCase(
		label: "setext headings",
		source: """
			Mozilla Public License Version 2.0
			==================================

			1. Definitions
			---------------
			""",
		expected: [
			.heading(level: 1, source: "Mozilla Public License Version 2.0"),
			.heading(level: 2, source: "1. Definitions"),
		]
	),
	MarkdownParserSyntaxCase(
		label: "leading frontmatter",
		source: """
			---
			title: Changelog
			description: Project release history.
			---

			# Changelog

			- Added a website.
			""",
		expected: [
			.heading(level: 1, source: "Changelog"),
			.bullet("Added a website."),
		]
	),
	MarkdownParserSyntaxCase(
		label: "GitHub alert markers",
		source: """
			> [!IMPORTANT]
			> Keep the runtime components together.
			""",
		expected: [
			.paragraph("**Important**"),
			.paragraph("Keep the runtime components together."),
		]
	),
	MarkdownParserSyntaxCase(
		label: "numbered recovery steps",
		source: """
			## Try this

			1. Choose **Retry** once.
			2. Choose **Retry** again after closing the game.
			""",
		expected: [
			.heading(level: 2, source: "Try this"),
			.numbered(1, "Choose **Retry** once."),
			.numbered(2, "Choose **Retry** again after closing the game."),
		]
	),
]

@Test(
	"MarkdownParser recognizes supported document syntax",
	arguments: markdownParserSyntaxCases
)
func markdownParserRecognizesDocumentSyntax(testCase: MarkdownParserSyntaxCase) {
	#expect(
		MarkdownParser(source: testCase.source).blocks == testCase.expected,
		Comment(rawValue: testCase.label)
	)
}
