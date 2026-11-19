// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Testing

@Test(arguments: [
	("manifest.json", GameRegion.global),
	("https://ak-tw.hg-cdn.com/uiCaUeGDB2htwXSv/72.0/update/6/6/Windows/files", .taiwan),
])
func packageValidationAcceptsRelativeYostarPathsAndAbsoluteGryphlineURLs(
	value: String,
	region: GameRegion
) throws {
	try YostarContractProbe.validateGameConfigurationPath(value, region: region)
}

@Test(arguments: [
	"http://ak-tw.hg-cdn.com/game/files",
	"https://evil.example/game/files",
	"https://ak-tw.hg-cdn.com:8443/game/files",
	"https://user@ak-tw.hg-cdn.com/game/files",
])
func gryphlinePackageValidationRejectsUntrustedAbsoluteURLs(value: String) {
	#expect(throws: Error.self) {
		try YostarContractProbe.validateGameConfigurationPath(value, region: .taiwan)
	}
}
