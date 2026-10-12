// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Testing

@testable import ArknightsLauncherUI

@MainActor
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
