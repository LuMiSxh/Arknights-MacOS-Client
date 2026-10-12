// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Testing

@testable import ArknightsCustomization

private let remoteManifest = Data(
	#"{"schemaVersion":1,"tags":{"global-1":["amiya","kal'tsit"],"global-9999":["new event"]}}"#
		.utf8)
private let bundledTags = ["global-1": ["amiya"], "global-2": ["texas"]]

@Test
func tagManifestsWithAnotherSchemaAreRejected() async throws {
	#expect(throws: DecodingError.self) {
		try WallpaperTagCatalog.decode(Data(#"{"schemaVersion":2,"tags":{}}"#.utf8))
	}
	#expect(try WallpaperTagCatalog.decode(remoteManifest)["global-9999"] == ["new event"])

	// A missing remote manifest keeps the bundled tags and writes no cache.
	let root = temporaryPresetRoot()
	defer { try? FileManager.default.removeItem(at: root) }
	let store = WallpaperTagStore(bundled: bundledTags)
	let service = tagService(root: root, path: "/missing.json", store: store)

	#expect(await !service.refreshWallpaperTags())
	#expect(store.tags == bundledTags)
	let cacheFile = await service.cachedWallpaperTagsFile
	#expect(!FileManager.default.fileExists(atPath: cacheFile.path))
}

private func temporaryPresetRoot() -> URL {
	FileManager.default.temporaryDirectory.appending(
		path: "WallpaperTagStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
}

private func tagService(
	root: URL, path: String, store: WallpaperTagStore
)
	-> PresetCatalogService
{
	let configuration = URLSessionConfiguration.ephemeral
	configuration.protocolClasses = [TagManifestURLProtocol.self]
	return PresetCatalogService(
		cacheDirectory: root,
		session: URLSession(configuration: configuration),
		wallpaperTagsURL: URL(string: "https://raw.githubusercontent.com\(path)")!,
		tagStore: store,
		log: LauncherLog(fileURL: root.appending(path: "launcher.log"))
	)
}

/// Serves the manifest for `/tags.json` and 404 for anything else, without shared state.
private final class TagManifestURLProtocol: URLProtocol, @unchecked Sendable {
	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		guard let url = request.url else { return }
		let found = url.path == "/tags.json"
		guard
			let response = HTTPURLResponse(
				url: url, statusCode: found ? 200 : 404, httpVersion: "HTTP/1.1",
				headerFields: nil)
		else { return }
		client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
		if found { client?.urlProtocol(self, didLoad: remoteManifest) }
		client?.urlProtocolDidFinishLoading(self)
	}

	override func stopLoading() {}
}
