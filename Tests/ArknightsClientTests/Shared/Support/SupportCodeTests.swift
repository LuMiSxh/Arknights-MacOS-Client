// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

private struct SupportCodeFixture: Decodable {
	let code: String
	let domain: String
}

@Test
func supportCodesUseStableBareWordsAndDocumentationRoutes() {
	for code in SupportCode.allCases {
		#expect(SupportCode.hasValidSyntax(code.rawValue))
		#expect(SupportCode.isPublished(code.rawValue))
		#expect(code.troubleshootingURL.query == nil)
		#expect(
			code.troubleshootingURL.absoluteString
				== "https://lumisxh.github.io/Arknights-MacOS-Client/help/errors/\(code.rawValue.lowercased())/"
		)
	}
	#expect(!SupportCode.hasValidSyntax("AKC-VIRGA"))
	#expect(!SupportCode.hasValidSyntax("Virga"))
	#expect(!SupportCode.isPublished("CLOUD"))
}

@Test
func supportCodeRegistryMatchesThePublicDocumentationFixture() throws {
	let repositoryRoot = (0..<5).reduce(URL(filePath: #filePath)) { url, _ in
		url.deletingLastPathComponent()
	}
	let registryURL = repositoryRoot.appending(
		path: "docs/help/errors/registry.json"
	)
	let fixtures = try JSONDecoder().decode(
		[SupportCodeFixture].self,
		from: Data(contentsOf: registryURL)
	)

	#expect(Set(fixtures.map(\.code)) == Set(SupportCode.allCases.map(\.rawValue)))
	#expect(fixtures.allSatisfy { !$0.domain.isEmpty })
	#expect(fixtures.map(\.code).count == Set(fixtures.map(\.code)).count)
}

@Test
func supportCodesLoadEmbeddedRecoverySectionsAndResolveWebsiteLinks() throws {
	for code in SupportCode.allCases {
		let markdown = try #require(
			code.bundledTroubleshootingMarkdown()
		)
		#expect(markdown.hasPrefix("## Try this"))
		#expect(!markdown.contains("\n# \(code.rawValue)\n"))
	}

	let sepia = try #require(
		SupportCode.sepia.bundledTroubleshootingMarkdown()
	)
	#expect(
		sepia.contains(
			"https://lumisxh.github.io/Arknights-MacOS-Client/help/runtime-compatibility/"
		)
	)
	#expect(
		sepia.contains(
			"https://lumisxh.github.io/Arknights-MacOS-Client/help/errors/anemone/"
		)
	)
}
