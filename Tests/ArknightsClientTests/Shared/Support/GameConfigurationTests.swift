// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsClient

@Test(
	arguments: [
		("30GB", Int64(30_000_000_000)),
		("38.5 GB", Int64(38_500_000_000)),
		("512MB", Int64(512_000_000)),
		("2TB", Int64(2_000_000_000_000)),
	]
)
func byteSizeParsesRecognizedUnits(input: String, expected: Int64) {
	#expect(GameConfiguration.parseByteSize(input) == expected)
}

@Test
func byteSizeRejectsUnrecognizedInput() {
	#expect(GameConfiguration.parseByteSize("") == nil)
	#expect(GameConfiguration.parseByteSize("unknown") == nil)
}
