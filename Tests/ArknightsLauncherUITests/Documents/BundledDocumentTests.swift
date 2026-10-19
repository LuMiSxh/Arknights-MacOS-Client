// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsLauncherUI

@MainActor
@Test
func thirdPartyNoticesLoadFromTheCompiledDeflateResource() async throws {
	let storage = try TemporaryDirectory("bundled-document")
	defer { storage.remove() }
	let directory = storage.url
	let source = "# Third-party notices\n\n| A | 1 |\n"
	let compressed = try (Data(source.utf8) as NSData).compressed(using: .zlib) as Data
	try compressed.write(to: directory.appending(path: "ThirdPartyNotices.deflate"))
	let bundle = try #require(Bundle(url: directory))

	#expect(try BundledDocument.thirdPartyNotices.load(bundle: bundle) == source)
	let parsed = try await BundledDocument.thirdPartyNotices.loadAndParse(bundle: bundle)
	#expect(!parsed.blocks.isEmpty)
}
