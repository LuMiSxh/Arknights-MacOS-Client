// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCore

@Test
func packagedResourcesLoadFromTheSwiftPMBundle() throws {
	let tags = try BundledResource.wallpaperTags.data()
	#expect(!tags.isEmpty)
	for resource in [
		BundledResource.appIconTintSource, .gameIconBackground, .operatorIconFrame,
	] {
		#expect(throws: Never.self) { _ = try resource.url() }
	}
}
