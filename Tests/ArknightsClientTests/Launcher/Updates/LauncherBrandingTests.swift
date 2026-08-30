// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import Testing

@testable import ArknightsClient

@Test
func brandingDecodesOfficialSnakeCaseResponse() throws {
	let json = #"""
		{
		  "launcher_background_img": "https://example.com/launcher.jpg",
		  "launcher_background_img_crc64": "10730643096684735589",
		  "copyright_information": "Copyright notice",
		  "privacy_policy": "https://example.com/privacy",
		  "user_agreement": "https://example.com/terms",
		  "notice_pop_open": true,
		  "notice_content": "<p>Scheduled maintenance</p>"
		}
		"""#
	let decoder = JSONDecoder()
	decoder.keyDecodingStrategy = .convertFromSnakeCase

	let branding = try decoder.decode(LauncherBranding.self, from: Data(json.utf8))

	#expect(branding.launcherBackgroundImage?.absoluteString == "https://example.com/launcher.jpg")
	#expect(branding.launcherBackgroundImageCRC64 == "10730643096684735589")
	#expect(branding.copyrightInformation == "Copyright notice")
	#expect(branding.privacyPolicy?.absoluteString == "https://example.com/privacy")
	#expect(branding.userAgreement?.absoluteString == "https://example.com/terms")
	#expect(branding.noticePopOpen == true)
	#expect(branding.noticeContent == "<p>Scheduled maintenance</p>")
}

@Test
func artworkCacheRestoresTheLastActiveImagePerRegion() async throws {
	let directory = FileManager.default.temporaryDirectory.appending(
		path: "ArtworkCacheTests.\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	defer { try? FileManager.default.removeItem(at: directory) }
	try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	let imageData = try #require(
		Data(
			base64Encoded:
				"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zf9sAAAAASUVORK5CYII="
		)
	)
	try imageData.write(to: directory.appending(path: "artwork-key.jpg"))
	let cache = ArtworkCache(directory: directory)
	let branding = LauncherBranding(
		launcherBackgroundImage: URL(string: "https://example.com/artwork.jpg"),
		launcherBackgroundImageCRC64: "artwork-key",
		copyrightInformation: nil,
		privacyPolicy: nil,
		userAgreement: nil,
		noticePopOpen: nil,
		noticeContent: nil
	)

	_ = try await cache.imageData(for: branding, region: .global)

	#expect(try cache.cachedActiveImageData(for: .global) != nil)
	#expect(try cache.cachedActiveCacheKey(for: .global) == "artwork-key")
	#expect(cache.cacheKey(for: branding) == "artwork-key")
	#expect(try cache.cachedActiveImageData(for: .korea) == nil)
}

@Test
func artworkCacheKeepsTheNewestSameRegionRequestActive() async throws {
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
		launcherBackgroundImage: URL(string: "https://" + host + ".example.com/" + host + ".jpg"),
		launcherBackgroundImageCRC64: key, copyrightInformation: nil, privacyPolicy: nil,
		userAgreement: nil, noticePopOpen: nil, noticeContent: nil)
}

@Test
func officialWordmarkURLsAndCachesAreRegionSpecific() throws {
	#expect(
		ArtworkCache.officialLogoURL(for: .global).absoluteString
			== "https://webusstatic.yo-star.com/arknights-us/arknights-us-website/main/h5/assets/logo-4f95ced5.png"
	)
	#expect(
		ArtworkCache.officialLogoURL(for: .japan).absoluteString
			== "https://webusstatic.yo-star.com/arknights-jp/arknights-jp-website/main/arknights-jp-website/assets/logo-0bd0cb04.png"
	)
	#expect(
		ArtworkCache.officialLogoURL(for: .korea).absoluteString
			== "https://webusstatic.yo-star.com/arknights-kr/arknights-kr-website/main/arknights-kr-website/assets/logo-7510becf.png"
	)

	let directory = FileManager.default.temporaryDirectory.appending(
		path: "RegionalWordmarkCacheTests.\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	defer { try? FileManager.default.removeItem(at: directory) }
	try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	let globalData = Data("global-wordmark".utf8)
	let japanData = Data("japan-wordmark".utf8)
	try globalData.write(
		to: directory.appending(path: "official-arknights-logo-global.png")
	)
	try japanData.write(to: directory.appending(path: "official-arknights-logo-japan.png"))
	let cache = ArtworkCache(directory: directory)

	#expect(try cache.cachedOfficialLogoData(for: .global) == globalData)
	#expect(try cache.cachedOfficialLogoData(for: .japan) == japanData)
	#expect(try cache.cachedOfficialLogoData(for: .korea) == nil)
}

@Test
func japanWordmarkRecoversFromMalformedCacheAndCorruptResponse() async throws {
	let directory = FileManager.default.temporaryDirectory.appending(
		path: "JapanWordmarkRetryTests.\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	defer { try? FileManager.default.removeItem(at: directory) }
	try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	try Data("not-an-image".utf8).write(
		to: directory.appending(path: "official-arknights-logo-japan.png")
	)

	let imageData = try #require(
		Data(
			base64Encoded:
				"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zf9sAAAAASUVORK5CYII="
		)
	)
	RegionalLogoURLProtocol.configureJapan(
		responses: [
			HTTPURLResponse(
				url: ArtworkCache.officialLogoURL(for: .japan),
				statusCode: 200,
				httpVersion: nil,
				headerFields: nil
			)!,
			HTTPURLResponse(
				url: ArtworkCache.officialLogoURL(for: .japan),
				statusCode: 200,
				httpVersion: nil,
				headerFields: nil
			)!,
		],
		bodies: [Data("<!doctype html>".utf8), imageData]
	)
	defer { RegionalLogoURLProtocol.resetJapan() }

	let configuration = URLSessionConfiguration.ephemeral
	configuration.protocolClasses = [RegionalLogoURLProtocol.self]
	let cache = ArtworkCache(
		session: URLSession(configuration: configuration),
		directory: directory
	)

	let loaded = try await cache.officialLogoData(for: .japan)
	#expect(loaded == imageData)
	#expect(try cache.cachedOfficialLogoData(for: .japan) == imageData)
	#expect(RegionalLogoURLProtocol.requestCountValue == 2)
}

private final class RegionalLogoURLProtocol: URLProtocol, @unchecked Sendable {
	static let imageData = Data(
		base64Encoded:
			"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zf9sAAAAASUVORK5CYII="
	)!
	private static let lock = NSLock()
	private static let release = DispatchSemaphore(value: 0)
	nonisolated(unsafe) static var responses: [HTTPURLResponse] = []
	nonisolated(unsafe) static var bodies: [Data] = []
	nonisolated(unsafe) static var requestCount = 0
	nonisolated(unsafe) static var delayFirst = false
	nonisolated(unsafe) static var firstRequestStarted = false

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		if request.url?.host == "first.example.com" {
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
		if request.url?.host == "second.example.com" {
			finish(Self.imageData)
			return
		}
		_ = Self.lock.withLock {
			Self.requestCount += 1
			return false
		}
		let result = Self.lock.withLock { () -> (HTTPURLResponse, Data)? in
			guard !Self.responses.isEmpty else { return nil }
			let response = Self.responses.removeFirst()
			let body = Self.bodies.isEmpty ? Data() : Self.bodies.removeFirst()
			return (response, body)
		}
		guard let (response, body) = result else {
			client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
			return
		}
		client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
		if response.statusCode == 200 { client?.urlProtocol(self, didLoad: body) }
		client?.urlProtocolDidFinishLoading(self)
	}

	override func stopLoading() {}

	static var requestCountValue: Int {
		lock.withLock { requestCount }
	}

	private func finish(_ data: Data) {
		let response = HTTPURLResponse(
			url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
		client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
		client?.urlProtocol(self, didLoad: data)
		client?.urlProtocolDidFinishLoading(self)
	}

	static func configureJapan(responses: [HTTPURLResponse], bodies: [Data]) {
		lock.withLock {
			Self.responses = responses
			Self.bodies = bodies
			Self.requestCount = 0
		}
	}

	static func beginOrdering() {
		lock.withLock {
			delayFirst = true
			firstRequestStarted = false
		}
	}
	static func resetJapan() {
		lock.withLock {
			responses = []
			bodies = []
			requestCount = 0
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
