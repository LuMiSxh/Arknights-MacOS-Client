// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func publisherArtifactSourcesAndRedirectsUseTheSameHTTPSPolicy() throws {
	let cases: [(GameRegion, String, Bool)] = [
		(.global, "https://cdn.unverified.example/game/file", false),
		(.global, "https://127.0.0.1/game/file", false),
		(.global, "https://[2001:db8::1]/game/file", false),
		(.global, "https://bücher.example/game/file", false),
		(.global, "https://foo%20bar/game/file", false),
		(.global, "https://host%2fpath.example/game/file", false),
		(.global, "https://host%5bname%5d.example/game/file", false),
		(.japan, "http://cdn.example/game/file", false),
		(.korea, "https://user:pass@launcher-pkg-ark-kr.yo-star.com/game/file", false),
		(.china, "https://ak.hycdn.cn/game/file", true),
		(.chinaBilibili, "https://cdn.hycdn.cn/game/file", true),
		(.china, "https://bad%20host.hycdn.cn/game/file", false),
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

@Test(arguments: [
	(GameRegion.global, "https://launcher-pkg-ark-en.yo-star.com/game/file", true),
	(.global, "https://launcher-pkg-ark-en-bk.yo-star.com/game/file", true),
	(.global, "https://yo-star.com/game/file", true),
	(.global, "https://LAUNCHER-PKG-ARK-EN.YO-STAR.COM/game/file", true),
	(.japan, "https://launcher-pkg-ark-jp.yo-star.com/game/file", true),
	(.japan, "https://launcher-pkg-ark-jp-bk.yo-star.com/game/file", true),
	(.korea, "https://launcher-pkg-ark-kr.yo-star.com/game/file", true),
	(.korea, "https://launcher-pkg-ark-kr-bk.yo-star.com/game/file", true),
	(.global, "https://yo-star.com.evil.com/game/file", false),
	(.global, "https://evilyo-star.com/game/file", false),
	(.global, "https://yo-star.com@evil.com/game/file", false),
	(.global, "https://evil.com@yo-star.com/game/file", false),
	(.global, "https://launcher-pkg-ark-en.yo-star.com.evil.com/game/file", false),
	(.global, "http://launcher-pkg-ark-en.yo-star.com/game/file", false),
	(.japan, "https://cdn.example/game/file", false),
	(.korea, "https://yo-star.co/game/file", false),
])
func yostarSourcesRequireTheYostarDomain(
	region: GameRegion,
	rawURL: String,
	expected: Bool
) throws {
	let url = try #require(URL(string: rawURL))
	#expect(DownloadHTTPPolicy.isAllowedSource(url, for: region) == expected)
	#expect(DownloadHTTPPolicy.redirectValidator(for: region)(url) == expected)
}
