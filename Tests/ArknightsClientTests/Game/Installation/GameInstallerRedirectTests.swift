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
func nonGryphlineDownloadRedirectsKeepExistingSessionSemantics() {
	#expect(GameInstaller.downloadRedirectValidator(for: .global) == nil)
	#expect(GameInstaller.downloadRedirectValidator(for: .china) == nil)
}
