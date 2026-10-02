// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test(arguments: BundledDocumentLoadMode.allCases)
func bundledDocumentReportsMissingResourcesExplicitly(mode: BundledDocumentLoadMode) async throws {
	let bundle = try #require(Bundle(url: URL(filePath: "/tmp")))

	let error: BundledDocument.LoadError?
	switch mode {
	case .synchronous:
		error = #expect(throws: BundledDocument.LoadError.self) {
			_ = try BundledDocument.changelog.load(bundle: bundle)
		}
	case .asynchronous:
		error = await #expect(throws: BundledDocument.LoadError.self) {
			_ = try await BundledDocument.changelog.loadAndParse(bundle: bundle)
		}
	}

	#expect(error == .missingResource(name: "CHANGELOG", fileExtension: "md"))
}

enum BundledDocumentLoadMode: String, CaseIterable, Sendable {
	case synchronous
	case asynchronous
}
