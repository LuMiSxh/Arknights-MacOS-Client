// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test(arguments: BundledDocumentLoadMode.allCases)
func bundledDocumentReportsMissingResourcesExplicitly(mode: BundledDocumentLoadMode) async throws {
	let bundle = try #require(Bundle(url: URL(filePath: "/tmp")))

	let error: BundledResourceError?
	switch mode {
	case .synchronous:
		error = #expect(throws: BundledResourceError.self) {
			_ = try BundledDocument.changelog.load(bundle: bundle)
		}
	case .asynchronous:
		error = await #expect(throws: BundledResourceError.self) {
			_ = try await BundledDocument.changelog.loadAndParse(bundle: bundle)
		}
	}

	#expect(error == .missing(path: "CHANGELOG.md"))
}

enum BundledDocumentLoadMode: String, CaseIterable, Sendable {
	case synchronous
	case asynchronous
}

@Test
func thirdPartyNoticesLoadFromTheCompiledDeflateResource() async throws {
	let directory = FileManager.default.temporaryDirectory
		.appending(path: "bundled-document-\(UUID().uuidString)", directoryHint: .isDirectory)
	try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	defer { try? FileManager.default.removeItem(at: directory) }
	let source = "# Third-party notices\n\n| A | 1 |\n"
	let compressed = try (Data(source.utf8) as NSData).compressed(using: .zlib) as Data
	try compressed.write(to: directory.appending(path: "ThirdPartyNotices.deflate"))
	let bundle = try #require(Bundle(url: directory))

	#expect(try BundledDocument.thirdPartyNotices.load(bundle: bundle) == source)
	let parsed = try await BundledDocument.thirdPartyNotices.loadAndParse(bundle: bundle)
	#expect(!parsed.blocks.isEmpty)
}
