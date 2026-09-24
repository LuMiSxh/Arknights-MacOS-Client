// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func bundledDocumentReportsMissingResourcesExplicitly() throws {
	let bundle = try #require(Bundle(url: URL(filePath: "/tmp")))

	let error = #expect(throws: BundledDocument.LoadError.self) {
		_ = try BundledDocument.changelog.load(bundle: bundle)
	}

	#expect(error == .missingResource(name: "CHANGELOG", fileExtension: "md"))
}

@Test
func bundledDocumentAsyncLoadReportsMissingResourcesExplicitly() async throws {
	let bundle = try #require(Bundle(url: URL(filePath: "/tmp")))

	let error = await #expect(throws: BundledDocument.LoadError.self) {
		_ = try await BundledDocument.changelog.loadAndParse(bundle: bundle)
	}

	#expect(error == .missingResource(name: "CHANGELOG", fileExtension: "md"))
}
