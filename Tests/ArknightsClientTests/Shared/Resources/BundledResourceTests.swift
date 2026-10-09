// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

private struct Sample: Codable, Equatable {
	let value: Int
}

private func makeBundle(_ files: [String: Data]) throws -> (Bundle, URL) {
	let directory = FileManager.default.temporaryDirectory
		.appending(path: "bundled-resource-\(UUID().uuidString)", directoryHint: .isDirectory)
	for (path, data) in files {
		let url = directory.appending(path: path)
		try FileManager.default.createDirectory(
			at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
		try data.write(to: url)
	}
	try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	return (try #require(Bundle(url: directory)), directory)
}

@Test(arguments: [BundledResource.Encoding.identity, .deflate])
func bundledResourceRoundTripsTextAndJSON(encoding: BundledResource.Encoding) throws {
	let json = Data(#"{"value":7}"#.utf8)
	let stored =
		encoding == .deflate ? try (json as NSData).compressed(using: .zlib) as Data : json
	let (bundle, directory) = try makeBundle(["Sample.json": stored])
	defer { try? FileManager.default.removeItem(at: directory) }
	let resource = BundledResource(file: "Sample.json", origin: .app, encoding: encoding)

	#expect(try resource.data(in: bundle) == json)
	#expect(try resource.text(in: bundle) == #"{"value":7}"#)
	#expect(try resource.decode(Sample.self, in: bundle) == Sample(value: 7))
}

@Test
func bundledResourceReportsMissingUnreadableAndCorruptContent() throws {
	let (bundle, directory) = try makeBundle([
		"Bad.deflate": Data("not deflate data".utf8),
		"Latin.txt": Data([0xFF, 0xFE, 0x41]),
		"Bad.json": Data("{".utf8),
	])
	defer { try? FileManager.default.removeItem(at: directory) }

	let missing = BundledResource(file: "Nothing.txt", origin: .app)
	#expect(throws: BundledResourceError.missing(path: "Nothing.txt")) {
		_ = try missing.data(in: bundle)
	}
	let deflate = BundledResource(file: "Bad.deflate", origin: .app, encoding: .deflate)
	#expect(throwsCorrupt { _ = try deflate.data(in: bundle) })
	let text = BundledResource(file: "Latin.txt", origin: .app)
	#expect(throwsCorrupt { _ = try text.text(in: bundle) })
	let json = BundledResource(file: "Bad.json", origin: .app)
	#expect(throwsCorrupt { _ = try json.decode(Sample.self, in: bundle) })
}

private func throwsError(_ body: () throws -> Void) -> BundledResourceError? {
	do { try body() } catch { return error as? BundledResourceError }
	return nil
}

private func throwsCorrupt(_ body: () throws -> Void) -> Bool {
	if case .corrupt = throwsError(body) { return true }
	return false
}

@Test
func bundledResourceResolvesDirectoriesAndNestedFiles() throws {
	let (bundle, directory) = try makeBundle(["SupportArticles/sepia.md": Data("# Sepia".utf8)])
	defer { try? FileManager.default.removeItem(at: directory) }
	let article = BundledResource.supportArticles.file("sepia.md")

	#expect(article.path == "SupportArticles/sepia.md")
	#expect(article.origin == .app)
	#expect(try article.text(in: bundle) == "# Sepia")
	#expect(
		try BundledResource.supportArticles.url(in: bundle).lastPathComponent == "SupportArticles")
	#expect(throws: BundledResourceError.missing(path: "Compatibility")) {
		_ = try BundledResource.compatibility.url(in: bundle)
	}
}

@Test
func bundledResourceRegistryHasUniquePathsAndKnownEncodings() {
	let paths = BundledResource.all.map(\.path)
	#expect(Set(paths).count == paths.count)
	#expect(BundledResource.all.filter { $0.encoding == .deflate } == [.thirdPartyNotices])
	#expect(
		BundledResource.all.filter { $0.kind == .directory }.allSatisfy { $0.encoding == .identity }
	)
}

@Test
func packagedResourcesLoadFromTheSwiftPMBundle() throws {
	let tags = try BundledResource.wallpaperTags.data()
	#expect(!tags.isEmpty)
	for resource in [
		BundledResource.appIconTintSource, .gameIconBackground, .operatorIconFrame,
	] {
		#expect(throws: Never.self) { _ = try resource.url() }
	}
}
