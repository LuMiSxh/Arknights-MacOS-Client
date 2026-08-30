// SPDX-License-Identifier: MPL-2.0

import Foundation
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

@Test(
	arguments: [
		"-1 GB",
		"NaN GB",
		"infinity GB",
		"1e3 GB",
		"9223372036854775808 GB",
		"100000000000000000000 TB",
	]
)
func byteSizeRejectsNonFiniteNegativeAndOverflowValues(input: String) {
	#expect(GameConfiguration.parseByteSize(input) == nil)
}

@Test
func byteSizeAcceptsValuesWithinInt64Range() {
	#expect(GameConfiguration.parseByteSize("9223372036 GB") == 9_223_372_036_000_000_000)
}

@Test(
	arguments: [
		"",
		"unknown",
		"NaN GB",
		"infinity GB",
		"1e3 GB",
		"9223372036854775808 GB",
		"100000000000000000000 TB",
	]
)
func gameConfigurationDecoderRejectsInvalidDecompressionSizes(size: String) {
	#expect(throws: DecodingError.self) {
		try JSONDecoder().decode(GameConfiguration.self, from: configurationJSON(size: size))
	}
}

@Test(
	arguments: [
		"",
		".",
		"..",
		"nested/Arknights.exe",
		"nested\\Arknights.exe",
		"Arknights\n.exe",
	]
)
func gameConfigurationRejectsUnsafeExecutableBasenames(name: String) {
	#expect(throws: DecodingError.self) {
		try JSONDecoder().decode(GameConfiguration.self, from: configurationJSON(executable: name))
	}
}

private func configurationJSON(
	executable: String = "Arknights.exe",
	size: String = "1 GB"
) -> Data {
	Data(
		"""
		{"gameLowestVersion":"1","gameLatestVersion":"1","gameLatestFilePath":"manifest","gameStartExeName":"\(executable)","gameStartParams":[],"gameUninstallScript":"","decompressionSize":"\(size)"}
		""".utf8)
}
