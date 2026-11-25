// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Synchronization
import Testing

@testable import ArknightsCustomization
@testable import ArknightsInfrastructure

@Suite
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
		#expect(await EpochImageURLProtocol.waitForRequestStart())
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
	private struct RequestState {
		var startedSignal = Signal()
		var count = 0
	}

	private static let state = Mutex(RequestState())

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		let (started, isFirstRequest) = Self.state.withLock { state -> (Signal, Bool) in
			state.count += 1
			return (state.startedSignal, state.count == 1)
		}
		started.fire()
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

	static func waitForRequestStart() async -> Bool {
		let signal = state.withLock { $0.startedSignal }
		return await signal.wait(timeout: .seconds(10))
	}

	static func reset() {
		while gate.wait(timeout: .now()) == .success {}
		state.withLock { $0 = RequestState() }
	}

	static func release() { gate.signal() }
}
