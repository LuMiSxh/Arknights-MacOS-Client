// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import Foundation
import Testing

@testable import ArknightsCustomization

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
