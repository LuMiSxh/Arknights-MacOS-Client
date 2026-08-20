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
	#expect(try cache.cachedActiveImage(for: .korea) == nil)
}
