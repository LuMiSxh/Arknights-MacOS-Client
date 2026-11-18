// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCore

private struct SupportCodeFixture: Decodable {
	let code: String
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

	for code in SupportCode.allCases {
		#expect(code.bundledTroubleshootingMarkdown() != nil)
	}
}
