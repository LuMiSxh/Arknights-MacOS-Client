// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Suite(.serialized)
struct PresetCatalogServiceTests {
	@Test
	func galleryCacheIsClearedWhenTheLauncherVersionChanges() throws {
		let fileManager = FileManager.default
		let root = fileManager.temporaryDirectory.appending(
			path: "PresetCatalogVersionTests-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		defer { try? fileManager.removeItem(at: root) }
		let log = LauncherLog(fileURL: root.appending(path: "launcher.log"))
		_ = PresetCatalogService(cacheDirectory: root, log: log, cacheGeneration: "1")
		let staleFile = root.appending(path: "stale.cache")
		try Data("stale".utf8).write(to: staleFile)

		_ = PresetCatalogService(cacheDirectory: root, log: log, cacheGeneration: "2")

		#expect(!fileManager.fileExists(atPath: staleFile.path))
		let marker = root.appending(path: AppConstants.Presets.cacheGenerationFilename)
		#expect(try String(contentsOf: marker, encoding: .utf8) == "2")
	}

	@Test
	func galleryRowsDecodeArrayWrappedImageURLs() throws {
		let data = Data(#"{"image1":["https://webusstatic.yo-star.com/wallpaper.jpg"]}"#.utf8)
		let row = try JSONDecoder().decode(YostarGalleryRow.self, from: data)

		#expect(row.image1 == "https://webusstatic.yo-star.com/wallpaper.jpg")
	}

	@Test
	func avatarIdentifiersAllowOnlyBoundedASCIIKeys() {
		#expect(PresetCatalogService.isValidAvatarIdentifier("char_002_amiya"))
		#expect(!PresetCatalogService.isValidAvatarIdentifier("char_../../escape"))
		#expect(!PresetCatalogService.isValidAvatarIdentifier("char_éxample"))
		#expect(
			!PresetCatalogService.isValidAvatarIdentifier(
				"char_" + String(repeating: "a", count: 100)
			)
		)
	}

	@Test
	func remoteAssetsRequireApprovedHTTPSHosts() {
		#expect(
			PresetCatalogService.isAllowedRemoteAssetURL(
				URL(string: "https://webusstatic.yo-star.com/image.png")!
			)
		)
		#expect(
			!PresetCatalogService.isAllowedRemoteAssetURL(
				URL(string: "http://webusstatic.yo-star.com/image.png")!
			)
		)
		#expect(
			!PresetCatalogService.isAllowedRemoteAssetURL(
				URL(string: "https://127.0.0.1/image.png")!
			)
		)
	}

	@Test
	func cacheKeysAreHashedIntoSinglePathComponents() async {
		let root = FileManager.default.temporaryDirectory.appending(
			path: "PresetCatalogServiceTests-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		defer { try? FileManager.default.removeItem(at: root) }
		let service = PresetCatalogService(
			cacheDirectory: root,
			log: LauncherLog(fileURL: root.appending(path: "launcher.log"))
		)

		let first = await service.cacheFileURL(for: "../../outside")
		let second = await service.cacheFileURL(for: "../../outside")

		#expect(first == second)
		#expect(first.deletingLastPathComponent() == root)
		#expect(first.lastPathComponent.count == 70)
		#expect(first.pathExtension == "cache")
	}

	@Test
	func existingImageCacheIsPrunedToItsBudget() async throws {
		let fileManager = FileManager.default
		let root = fileManager.temporaryDirectory.appending(
			path: "PresetCatalogCacheLimitTests-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		defer { try? fileManager.removeItem(at: root) }
		let service = PresetCatalogService(
			cacheDirectory: root,
			log: LauncherLog(fileURL: root.appending(path: "launcher.log"))
		)
		try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
		let older = root.appending(path: "older.cache")
		let newer = root.appending(path: "newer.cache")
		for url in [older, newer] {
			#expect(fileManager.createFile(atPath: url.path, contents: nil))
			let handle = try FileHandle(forWritingTo: url)
			try handle.truncate(atOffset: 140 * 1_024 * 1_024)
			try handle.close()
		}
		try fileManager.setAttributes(
			[.modificationDate: Date(timeIntervalSince1970: 1)],
			ofItemAtPath: older.path
		)
		try fileManager.setAttributes(
			[.modificationDate: Date(timeIntervalSince1970: 2)],
			ofItemAtPath: newer.path
		)
		await service.enforceImageCacheLimitIfNeeded()

		#expect(!fileManager.fileExists(atPath: older.path))
		#expect(fileManager.fileExists(atPath: newer.path))
	}

	@Test
	func invalidImagePayloadIsRejected() {
		#expect(throws: LauncherError.self) {
			try PresetCatalogService.validateImageData(
				Data("not an image".utf8),
				source: URL(string: "https://cdn.jsdelivr.net/image.png")!
			)
		}
	}

	@Test
	func smallPNGPassesImageValidation() throws {
		let data = try #require(
			Data(
				base64Encoded:
					"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zl1sAAAAASUVORK5CYII="
			)
		)

		try PresetCatalogService.validateImageData(
			data,
			source: URL(string: "https://cdn.jsdelivr.net/image.png")!
		)
	}

	@Test
	func truncatedJPEGFailsImageValidation() throws {
		let encoded =
			"/9j/4AAQSkZJRgABAQAASABIAAD/4QBARXhpZgAATU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAAAaADAAQAAAABAAAAAQAAAAD/wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9sAQwACAgICAgIDAgIDBQMDAwUGBQUFBQYIBgYGBgYICggICAgICAoKCgoKCgoKDAwMDAwMDg4ODg4PDw8PDw8PDw8P/9sAQwECAgIEBAQHBAQHEAsJCxAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQ/90ABAAB/9oADAMBAAIRAxEAPwD9/KKKKAP/2Q=="
		var data = try #require(Data(base64Encoded: encoded))
		try PresetCatalogService.validateImageData(
			data,
			source: URL(string: "https://webusstatic.yo-star.com/image.jpg")!
		)
		data.removeLast(2)

		#expect(throws: LauncherError.self) {
			try PresetCatalogService.validateImageData(
				data,
				source: URL(string: "https://webusstatic.yo-star.com/image.jpg")!
			)
		}
	}

	@Test
	func boundedLoaderRejectsChunkedResponsesAboveTheLimit() async {
		let configuration = URLSessionConfiguration.ephemeral
		configuration.protocolClasses = [BoundedDataURLProtocol.self]
		BoundedDataURLProtocol.body = Data(repeating: 0xAB, count: 32)
		defer { BoundedDataURLProtocol.body = Data() }
		let loader = BoundedHTTPDataLoader(session: URLSession(configuration: configuration))
		let request = URLRequest(url: URL(string: "https://cdn.jsdelivr.net/test.bin")!)

		await #expect(throws: LauncherError.self) {
			_ = try await loader.data(for: request, maximumBytes: 16)
		}
	}

	@Test
	func boundedLoaderRejectsRedirectsOutsideTheAssetAllowlist() async {
		let configuration = URLSessionConfiguration.ephemeral
		configuration.protocolClasses = [BoundedDataURLProtocol.self]
		BoundedDataURLProtocol.redirectURL = URL(string: "https://127.0.0.1/image.png")
		defer { BoundedDataURLProtocol.redirectURL = nil }
		let loader = BoundedHTTPDataLoader(
			session: URLSession(configuration: configuration),
			redirectValidator: PresetCatalogService.isAllowedRemoteAssetURL
		)
		let request = URLRequest(url: URL(string: "https://cdn.jsdelivr.net/image.png")!)

		await #expect(throws: LauncherError.self) {
			_ = try await loader.data(for: request, maximumBytes: 16)
		}
	}
}

private final class BoundedDataURLProtocol: URLProtocol, @unchecked Sendable {
	nonisolated(unsafe) static var body = Data()
	nonisolated(unsafe) static var redirectURL: URL?

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		let statusCode = Self.redirectURL == nil ? 200 : 302
		guard let url = request.url,
			let response = HTTPURLResponse(
				url: url,
				statusCode: statusCode,
				httpVersion: "HTTP/1.1",
				headerFields: nil
			)
		else { return }
		if let redirectURL = Self.redirectURL {
			var redirectRequest = URLRequest(url: redirectURL)
			redirectRequest.httpMethod = request.httpMethod
			client?.urlProtocol(self, wasRedirectedTo: redirectRequest, redirectResponse: response)
			return
		}
		client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
		for byte in Self.body {
			client?.urlProtocol(self, didLoad: Data([byte]))
		}
		client?.urlProtocolDidFinishLoading(self)
	}

	override func stopLoading() {}
}
