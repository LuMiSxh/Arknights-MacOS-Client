// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func publisherArtifactSourcesAndRedirectsUseTheSameHTTPSPolicy() throws {
	let cases: [(GameRegion, String, Bool)] = [
		(.global, "https://cdn.unverified.example/game/file", true),
		(.japan, "http://cdn.example/game/file", false),
		(.korea, "https://user:pass@cdn.example/game/file", false),
		(.china, "https://ak.hycdn.cn/game/file", true),
		(.chinaBilibili, "https://cdn.hycdn.cn/game/file", true),
		(.china, "https://launcher.hypergryph.com/game/file", false),
		(.china, "https://evilhycdn.cn/game/file", false),
		(.taiwan, "https://ak-tw.hg-cdn.com/game/file", true),
		(.taiwan, "https://launcher.hg-cdn.com/game/file", true),
		(.taiwan, "https://gl-utils-public.hg-cdn.com/game/file", true),
		(.taiwan, "https://launcher.gryphline.com/game/file", false),
		(.taiwan, "https://ak-tw.hg-cdn.com:8443/game/file", false),
		(.taiwan, "https://user:pass@ak-tw.hg-cdn.com/game/file", false),
	]

	for (region, rawURL, expected) in cases {
		let url = try #require(URL(string: rawURL))
		let allowedSource = DownloadHTTPPolicy.isAllowedSource(url, for: region)
		let allowedRedirect = DownloadHTTPPolicy.redirectValidator(for: region)(url)
		#expect(allowedSource == expected, "source: \(rawURL)")
		#expect(allowedRedirect == expected, "redirect: \(rawURL)")
	}

	var components = URLComponents()
	components.scheme = "https"
	components.path = "/game/file"
	let missingHostURL = try #require(components.url)
	#expect(missingHostURL.host == nil)
	for region in GameRegion.allCases {
		#expect(!DownloadHTTPPolicy.isAllowedSource(missingHostURL, for: region))
		#expect(!DownloadHTTPPolicy.redirectValidator(for: region)(missingHostURL))
	}
}
