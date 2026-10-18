// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCustomization
@testable import ArknightsInfrastructure

@Suite(.serialized)
struct PresetCatalogServiceTests {
	@Test
	func remoteAssetsRequireApprovedHTTPSHosts() async {
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
		let url = PresetCatalogService.validatedRemoteAssetURL(
			from: "https://webusstatic.yo-star.com/image.png?token=secret#frag")
		#expect(url?.absoluteString == "https://webusstatic.yo-star.com/image.png")

		let rows: [(label: String, body: Data, redirectURL: URL?)] = [
			("chunked body exceeds the byte limit", Data(repeating: 0xAB, count: 32), nil),
			(
				"redirect leaves the approved asset hosts", Data(),
				URL(string: "https://127.0.0.1/image.png")
			),
		]
		for row in rows {
			let route = StubURLProtocol.Route(chunkSize: 1)
			route.redirectURL = row.redirectURL
			route.handler = { request in
				(
					HTTPURLResponse(
						url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
						headerFields: nil)!,
					row.body
				)
			}
			let loader = BoundedHTTPDataLoader(
				session: route.session,
				maximumBufferedBytes: AppConstants.Network.maximumBufferedStreamBytes,
				redirectValidator: PresetCatalogService.isAllowedRemoteAssetURL
			)
			let request = URLRequest(url: URL(string: "https://cdn.jsdelivr.net/image.png")!)

			await #expect(throws: HTTPTransportError.self, Comment(rawValue: row.label)) {
				_ = try await loader.data(for: request, maximumBytes: 16)
			}
		}
	}

	@Test
	func cacheKeysAreHashedIntoSinglePathComponents() async throws {
		let temporary = try TemporaryDirectory("PresetCatalogServiceTests")
		defer { temporary.remove() }
		let root = temporary.url
		let service = PresetCatalogService(
			cacheDirectory: root,
			log: LauncherLog(fileURL: root.appending(path: "launcher.log"))
		)

		let first = await service.cacheFileURL(for: "../../outside")
		let second = await service.cacheFileURL(for: "../../outside")

		#expect(first == second)
		#expect(first.deletingLastPathComponent() == root)

		#expect(PresetCatalogService.isValidAvatarIdentifier("char_002_amiya"))
		#expect(!PresetCatalogService.isValidAvatarIdentifier("char_../../escape"))
		#expect(!PresetCatalogService.isValidAvatarIdentifier("char_éxample"))
		#expect(
			!PresetCatalogService.isValidAvatarIdentifier(
				"char_" + String(repeating: "a", count: 100)))
	}

	@Test
	func clearingTheCacheInvalidatesAnInFlightImageDownload() async throws {
		EpochImageURLProtocol.reset()
		defer {
			EpochImageURLProtocol.release()
			EpochImageURLProtocol.reset()
		}
		let temporary = try TemporaryDirectory("PresetCatalogEpochTests")
		defer { temporary.remove() }
		let root = temporary.url
		let configuration = URLSessionConfiguration.ephemeral
		configuration.protocolClasses = [EpochImageURLProtocol.self]
		let service = PresetCatalogService(
			cacheDirectory: root,
			session: URLSession(configuration: configuration),
			log: LauncherLog(fileURL: root.appending(path: "launcher.log"))
		)
		let url = URL(string: "https://cdn.jsdelivr.net/epoch.png")!
		let download = Task { try await service.imageData(for: url, cacheKey: "epoch") }
		while !EpochImageURLProtocol.isRequestStarted { await Task.yield() }
		try await service.clearCaches()
		EpochImageURLProtocol.release()
		_ = try? await download.value

		let cacheURL = await service.cacheFileURL(for: "epoch")
		#expect(!FileManager.default.fileExists(atPath: cacheURL.path))
	}
}

private final class EpochImageURLProtocol: URLProtocol, @unchecked Sendable {
	static let body = Data(
		base64Encoded:
			"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zf9sAAAAASUVORK5CYII="
	)!
	static let gate = DispatchSemaphore(value: 0)
	private static let lock = NSLock()
	nonisolated(unsafe) static var requestStarted = false
	nonisolated(unsafe) static var requestCount = 0

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		let isFirstRequest = Self.lock.withLock {
			Self.requestCount += 1
			Self.requestStarted = true
			return Self.requestCount == 1
		}
		if isFirstRequest { Self.gate.wait() }
		let response = HTTPURLResponse(
			url: request.url!,
			statusCode: 200,
			httpVersion: "HTTP/1.1",
			headerFields: nil
		)!
		client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
		client?.urlProtocol(self, didLoad: Self.body)
		client?.urlProtocolDidFinishLoading(self)
	}

	override func stopLoading() {}

	static var isRequestStarted: Bool {
		lock.withLock { requestStarted }
	}

	static func reset() {
		while gate.wait(timeout: .now()) == .success {}
		lock.withLock {
			requestStarted = false
			requestCount = 0
		}
	}

	static func release() { gate.signal() }
}
