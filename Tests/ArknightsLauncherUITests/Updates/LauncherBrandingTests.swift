// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import Foundation
import Testing

@testable import ArknightsCustomization
@testable import ArknightsLauncherUI

private func verifyArtworkCacheKeepsTheNewestSameRegionRequestActive() async throws {
	RegionalLogoURLProtocol.resetOrdering()
	defer {
		RegionalLogoURLProtocol.releaseFirst()
		RegionalLogoURLProtocol.resetOrdering()
	}
	let directory = FileManager.default.temporaryDirectory.appending(
		path: "ArtworkCacheOrderingTests.\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	defer { try? FileManager.default.removeItem(at: directory) }
	let configuration = URLSessionConfiguration.ephemeral
	configuration.protocolClasses = [RegionalLogoURLProtocol.self]
	let cache = ArtworkCache(
		session: URLSession(configuration: configuration),
		directory: directory
	)
	let first = testBranding(host: "first", key: "first")
	let second = testBranding(host: "second", key: "second")

	RegionalLogoURLProtocol.beginOrdering()
	let firstTask = Task { try await cache.imageData(for: first, region: .global) }
	while !RegionalLogoURLProtocol.isFirstRequestStarted() { await Task.yield() }
	let secondTask = Task { try await cache.imageData(for: second, region: .global) }
	_ = try await secondTask.value
	RegionalLogoURLProtocol.releaseFirst()
	_ = try await firstTask.value

	let activeKey = try cache.cachedActiveCacheKey(for: .global)
	#expect(activeKey == "second")
}

private func testBranding(host: String, key: String) -> LauncherBranding {
	LauncherBranding(
		launcherBackgroundImage: URL(string: "https://www.arknights.global/" + host + ".jpg"),
		launcherBackgroundImageCRC64: key, copyrightInformation: nil, privacyPolicy: nil,
		userAgreement: nil, noticePopOpen: nil, noticeContent: nil)
}

@Test
func artworkRedirectsUseTheSelectedPublisherHostModel() throws {
	let taiwanValidator = ArtworkCache.artworkRedirectValidator(for: .taiwan)
	#expect(taiwanValidator(URL(string: "https://gl-utils-public.hg-cdn.com/background.png")!))
	#expect(taiwanValidator(URL(string: "https://zh.wikifur.com/w/images/logo.png")!))
	#expect(!taiwanValidator(URL(string: "http://gl-utils-public.hg-cdn.com/background.png")!))
	#expect(!taiwanValidator(URL(string: "https://evil.example/background.png")!))
	#expect(!taiwanValidator(URL(string: "https://launcher.gryphline.com/background.png")!))
	#expect(
		!taiwanValidator(URL(string: "https://gl-utils-public.hg-cdn.com:8443/background.png")!))

	let chinaValidator = ArtworkCache.artworkRedirectValidator(for: .china)
	#expect(chinaValidator(URL(string: "https://ak.hycdn.cn/background.png")!))
	#expect(chinaValidator(URL(string: "https://zh.wikifur.com/w/images/logo.png")!))
}

@Suite(.serialized)
struct LauncherBrandingURLProtocolTests {
	@Test
	func artworkCacheKeepsTheNewestSameRegionRequestActive() async throws {
		try await verifyArtworkCacheKeepsTheNewestSameRegionRequestActive()
	}
}

private final class RegionalLogoURLProtocol: URLProtocol, @unchecked Sendable {
	static let imageData = Data(
		base64Encoded:
			"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zf9sAAAAASUVORK5CYII="
	)!
	private static let lock = NSLock()
	private static let release = DispatchSemaphore(value: 0)
	nonisolated(unsafe) static var delayFirst = false
	nonisolated(unsafe) static var firstRequestStarted = false

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		if request.url?.path == "/first.jpg" {
			let shouldDelay = Self.lock.withLock {
				Self.firstRequestStarted = true
				return Self.delayFirst
			}
			if shouldDelay {
				DispatchQueue.global(qos: .utility).async { [self] in
					Self.release.wait()
					finish(Self.imageData)
				}
				return
			}
		}
		if request.url?.path == "/second.jpg" {
			finish(Self.imageData)
			return
		}
		client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
	}

	override func stopLoading() {}

	private func finish(_ data: Data) {
		let response = HTTPURLResponse(
			url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
		client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
		client?.urlProtocol(self, didLoad: data)
		client?.urlProtocolDidFinishLoading(self)
	}

	static func beginOrdering() {
		lock.withLock {
			delayFirst = true
			firstRequestStarted = false
		}
	}
	static func resetOrdering() {
		while release.wait(timeout: .now()) == .success {}
		lock.withLock {
			delayFirst = false
			firstRequestStarted = false
		}
	}
	static func isFirstRequestStarted() -> Bool { lock.withLock { firstRequestStarted } }
	static func releaseFirst() { release.signal() }
}
