// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsClient

@Test
func byteSizeParsesWholeGigabytes() {
	#expect(GameConfiguration.parseByteSize("30GB") == 30_000_000_000)
}

@Test
func byteSizeParsesSpacedUnitAndDecimalValue() {
	#expect(GameConfiguration.parseByteSize("38.5 GB") == 38_500_000_000)
}

@Test
func byteSizeParsesOtherUnits() {
	#expect(GameConfiguration.parseByteSize("512MB") == 512_000_000)
	#expect(GameConfiguration.parseByteSize("2TB") == 2_000_000_000_000)
}

@Test
func byteSizeRejectsUnrecognizedInput() {
	#expect(GameConfiguration.parseByteSize("") == nil)
	#expect(GameConfiguration.parseByteSize("unknown") == nil)
}
