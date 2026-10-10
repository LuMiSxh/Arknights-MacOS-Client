// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCore

@Test(
	arguments: [
		(SupportLinks.thirdPartyNotices, "legal/third-party-notices/"),
		(SupportLinks.privacyNotice, "privacy/"),
	]
)
func legalLinksPointToPublishedDocumentationPages(url: URL, path: String) {
	#expect(
		url.absoluteString == "https://lumisxh.github.io/Arknights-MacOS-Client/" + path
	)
}
