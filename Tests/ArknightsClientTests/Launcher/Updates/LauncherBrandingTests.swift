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
func noticeFormatterRendersHTMLAsNativeText() throws {
	let notice = try #require(
		LauncherNoticeFormatter.notice(
			fromHTML: "<p><strong>Maintenance</strong><br>Servers restart at 10:00.</p>"
		)
	)
	let text = String(notice.content.characters)

	#expect(text.contains("Maintenance"))
	#expect(text.contains("Servers restart at 10:00."))
}

@Test
func brandingDecodesEmptyStringURLsAsNil() throws {
	let json = #"""
		{
		  "launcher_background_img": "https://example.com/launcher.png",
		  "launcher_background_img_crc64": "4615291511255606402",
		  "privacy_policy": "",
		  "user_agreement": ""
		}
		"""#
	let decoder = JSONDecoder()
	decoder.keyDecodingStrategy = .convertFromSnakeCase

	let branding = try decoder.decode(LauncherBranding.self, from: Data(json.utf8))

	#expect(branding.launcherBackgroundImage?.absoluteString == "https://example.com/launcher.png")
	#expect(branding.launcherBackgroundImageCRC64 == "4615291511255606402")
	#expect(branding.privacyPolicy == nil)
	#expect(branding.userAgreement == nil)
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

	#expect(try cache.cachedActiveImage(for: .global) != nil)
	#expect(try cache.cachedActiveCacheKey(for: .global) == "artwork-key")
	#expect(cache.cacheKey(for: branding) == "artwork-key")
	#expect(try cache.cachedActiveImage(for: .korea) == nil)
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
	RegionalLogoURLProtocol.responses = [
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
	]
	RegionalLogoURLProtocol.bodies = [Data("<!doctype html>".utf8), imageData]
	defer { RegionalLogoURLProtocol.reset() }

	let configuration = URLSessionConfiguration.ephemeral
	configuration.protocolClasses = [RegionalLogoURLProtocol.self]
	let cache = ArtworkCache(
		session: URLSession(configuration: configuration),
		directory: directory
	)

	let loaded = try await cache.officialLogoData(for: .japan)
	#expect(loaded == imageData)
	#expect(try cache.cachedOfficialLogoData(for: .japan) == imageData)
	#expect(RegionalLogoURLProtocol.requestCount == 2)
}

private final class RegionalLogoURLProtocol: URLProtocol, @unchecked Sendable {
	nonisolated(unsafe) static var responses: [HTTPURLResponse] = []
	nonisolated(unsafe) static var bodies: [Data] = []
	nonisolated(unsafe) static var requestCount = 0

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		Self.requestCount += 1
		guard !Self.responses.isEmpty else {
			client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
			return
		}
		let response = Self.responses.removeFirst()
		let body = Self.bodies.isEmpty ? Data() : Self.bodies.removeFirst()
		client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
		if response.statusCode == 200 { client?.urlProtocol(self, didLoad: body) }
		client?.urlProtocolDidFinishLoading(self)
	}

	override func stopLoading() {}

	static func reset() {
		responses = []
		bodies = []
		requestCount = 0
	}
}
