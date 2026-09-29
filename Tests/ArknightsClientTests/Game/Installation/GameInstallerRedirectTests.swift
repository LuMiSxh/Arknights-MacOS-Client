// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func gryphlineDownloadRedirectsRequireTrustedHTTPSHosts() throws {
	let validator = try #require(GameInstaller.downloadRedirectValidator(for: .taiwan))

	#expect(validator(URL(string: "https://ak-tw.hg-cdn.com/game/file")!))
	#expect(validator(URL(string: "https://launcher.hg-cdn.com/game/file")!))
	#expect(validator(URL(string: "https://gl-utils-public.hg-cdn.com/game/file")!))
	#expect(!validator(URL(string: "http://ak-tw.hg-cdn.com/game/file")!))
	#expect(!validator(URL(string: "https://evil.example/game/file")!))
	#expect(!validator(URL(string: "https://launcher.gryphline.com/game/file")!))
	#expect(!validator(URL(string: "https://ak-tw.hg-cdn.com:8443/game/file")!))
}

@Test
func downloadRedirectPoliciesPreserveVerifiedPublisherRoutes() throws {
	let yostar = try #require(GameInstaller.downloadRedirectValidator(for: .global))
	#expect(yostar(URL(string: "https://cdn.example/game/file")!))
	#expect(!yostar(URL(string: "http://cdn.example/game/file")!))
	#expect(!yostar(URL(string: "https://user@cdn.example/game/file")!))

	let hypergryph = try #require(GameInstaller.downloadRedirectValidator(for: .china))
	#expect(hypergryph(URL(string: "https://ak.hycdn.cn/game/file")!))
	#expect(!hypergryph(URL(string: "https://evil.example/game/file")!))
	#expect(!hypergryph(URL(string: "http://ak.hycdn.cn/game/file")!))
}
