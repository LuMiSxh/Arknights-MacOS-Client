// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
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
			let configuration = URLSessionConfiguration.ephemeral
			configuration.protocolClasses = [BoundedDataURLProtocol.self]
			BoundedDataURLProtocol.configure(body: row.body, redirectURL: row.redirectURL)
			defer { BoundedDataURLProtocol.reset() }
			let loader = BoundedHTTPDataLoader(
				session: URLSession(configuration: configuration),
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
		let root = FileManager.default.temporaryDirectory.appending(
			path: "PresetCatalogEpochTests-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		defer { try? FileManager.default.removeItem(at: root) }
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

private final class BoundedDataURLProtocol: URLProtocol, @unchecked Sendable {
	private static let lock = NSLock()
	nonisolated(unsafe) static var body = Data()
	nonisolated(unsafe) static var redirectURL: URL?

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		let (body, redirectURL) = Self.lock.withLock { (Self.body, Self.redirectURL) }
		let statusCode = redirectURL == nil ? 200 : 302
		guard let url = request.url,
			let response = HTTPURLResponse(
				url: url,
				statusCode: statusCode,
				httpVersion: "HTTP/1.1",
				headerFields: nil
			)
		else { return }
		if let redirectURL {
			var redirectRequest = URLRequest(url: redirectURL)
			redirectRequest.httpMethod = request.httpMethod
			client?.urlProtocol(self, wasRedirectedTo: redirectRequest, redirectResponse: response)
			return
		}
		client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
		for byte in body {
			client?.urlProtocol(self, didLoad: Data([byte]))
		}
		client?.urlProtocolDidFinishLoading(self)
	}

	override func stopLoading() {}

	static func configure(body: Data = Data(), redirectURL: URL? = nil) {
		lock.withLock {
			Self.body = body
			Self.redirectURL = redirectURL
		}
	}

	static func reset() {
		configure()
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
