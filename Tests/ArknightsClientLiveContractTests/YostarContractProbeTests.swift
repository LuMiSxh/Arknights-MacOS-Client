// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func gryphlinePackageValidationChecksTheAbsoluteURLAndItsPathSeparately() throws {
	try YostarContractProbe.validateGameConfigurationPath(
		"https://ak-tw.hg-cdn.com/uiCaUeGDB2htwXSv/72.0/update/6/6/Windows/files",
		region: .taiwan
	)
}

@Test
func gryphlinePackageValidationRejectsUntrustedAbsoluteURLs() {
	for value in [
		"http://ak-tw.hg-cdn.com/game/files",
		"https://evil.example/game/files",
		"https://ak-tw.hg-cdn.com:8443/game/files",
		"https://user@ak-tw.hg-cdn.com/game/files",
	] {
		#expect(throws: Error.self) {
			try YostarContractProbe.validateGameConfigurationPath(value, region: .taiwan)
		}
	}
}

@Test
func yostarPackageValidationKeepsRelativeManifestPaths() throws {
	try YostarContractProbe.validateGameConfigurationPath("manifest.json", region: .global)
}
