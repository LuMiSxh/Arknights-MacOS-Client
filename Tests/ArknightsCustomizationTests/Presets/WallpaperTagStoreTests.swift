// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
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
	let temporary = try TemporaryDirectory("WallpaperTagStoreTests")
	defer { temporary.remove() }
	let root = temporary.url
	let store = WallpaperTagStore(bundled: bundledTags)
	let service = tagService(root: root, path: "/missing.json", store: store)

	#expect(await !service.refreshWallpaperTags())
	#expect(store.tags == bundledTags)
	let cacheFile = await service.cachedWallpaperTagsFile
	#expect(!FileManager.default.fileExists(atPath: cacheFile.path))
}

private func tagService(
	root: URL, path: String, store: WallpaperTagStore
)
	-> PresetCatalogService
{
	let route = StubURLProtocol.Route()
	route.handler = { request in
		let url = request.url!
		let found = url.path == "/tags.json"
		let response = HTTPURLResponse(
			url: url, statusCode: found ? 200 : 404, httpVersion: "HTTP/1.1", headerFields: nil)!
		return (response, found ? remoteManifest : Data())
	}
	return PresetCatalogService(
		cacheDirectory: root,
		session: route.session,
		wallpaperTagsURL: URL(string: "https://raw.githubusercontent.com\(path)")!,
		tagStore: store,
		log: LauncherLog(fileURL: root.appending(path: "launcher.log"))
	)
}
