// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsClient

@Test
func markdownParserRecognizesTablesAndInlineSource() {
	let source = """
		# Components

		| Name | Version | Source |
		| --- | ---: | --- |
		| Wine | `11.15` | [Repository](https://example.com) |

		- Bundled with the launcher
		"""
	let blocks = MarkdownParser(source: source).blocks

	#expect(blocks.count == 3)
	#expect(blocks[0] == .heading(level: 1, source: "Components"))
	#expect(
		blocks[1]
			== .table([
				["Name", "Version", "Source"],
				["Wine", "`11.15`", "[Repository](https://example.com)"],
			]))
	#expect(blocks[2] == .bullet("Bundled with the launcher"))
}

@Test
func markdownParserTreatsSetextHeadingsAsHeadingsInsteadOfTables() {
	let blocks = MarkdownParser(
		source: """
			Mozilla Public License Version 2.0
			==================================

			1. Definitions
			---------------
			"""
	).blocks

	#expect(
		blocks == [
			.heading(level: 1, source: "Mozilla Public License Version 2.0"),
			.heading(level: 2, source: "1. Definitions"),
		]
	)
}

@Test
func markdownParserIgnoresLeadingFrontmatter() {
	let blocks = MarkdownParser(
		source: """
			---
			title: Changelog
			description: Project release history.
			---

			# Changelog

			- Added a website.
			"""
	).blocks

	#expect(
		blocks == [
			.heading(level: 1, source: "Changelog"),
			.bullet("Added a website."),
		]
	)
}

@Test
func markdownParserRemovesGitHubAlertMarkers() {
	let blocks = MarkdownParser(
		source: """
			> [!IMPORTANT]
			> Keep the runtime components together.
			"""
	).blocks

	#expect(
		blocks == [
			.paragraph("**Important**"),
			.paragraph("Keep the runtime components together."),
		]
	)
}

@Test
func markdownParserPreservesNumberedRecoverySteps() {
	let blocks = MarkdownParser(
		source: """
			## Try this

			1. Choose **Retry** once.
			2. Choose **Retry** again after closing the game.
			"""
	).blocks

	#expect(
		blocks == [
			.heading(level: 2, source: "Try this"),
			.numbered(1, "Choose **Retry** once."),
			.numbered(2, "Choose **Retry** again after closing the game."),
		]
	)
}
