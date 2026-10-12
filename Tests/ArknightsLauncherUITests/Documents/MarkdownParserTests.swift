// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsLauncherUI

struct MarkdownParserSyntaxCase: Identifiable, Sendable {
	let label: String
	let source: String
	let expected: [MarkdownBlock]

	var id: String { label }
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
