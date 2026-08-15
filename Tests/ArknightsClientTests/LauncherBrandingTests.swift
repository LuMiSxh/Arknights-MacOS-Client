// SPDX-License-Identifier: MPL-2.0

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
