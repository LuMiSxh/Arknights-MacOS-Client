// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCore

private struct SupportCodeFixture: Decodable {
	let code: String
	let domain: String
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

	for code in SupportCode.allCases {
		#expect(SupportCode.hasValidSyntax(code.rawValue))
		#expect(SupportCode.isPublished(code.rawValue))
		#expect(code.bundledTroubleshootingMarkdown() != nil)
	}
	#expect(!SupportCode.hasValidSyntax("AKC-VIRGA"))
	#expect(!SupportCode.isPublished("CLOUD"))
}
