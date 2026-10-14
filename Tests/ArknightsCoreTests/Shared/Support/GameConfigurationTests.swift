// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCore

@Test(
	arguments: [
		("", "1 GB"),
		(".", "1 GB"),
		("..", "1 GB"),
		("nested/Arknights.exe", "1 GB"),
		("nested\\Arknights.exe", "1 GB"),
		("Arknights\n.exe", "1 GB"),
		("Arknights.exe", ""),
		("Arknights.exe", "unknown"),
		("Arknights.exe", "NaN GB"),
		("Arknights.exe", "infinity GB"),
		("Arknights.exe", "1e3 GB"),
		("Arknights.exe", "9223372036854775808 GB"),
		("Arknights.exe", "100000000000000000000 TB"),
	]
)
func gameConfigurationRejectsUnsafeExecutableBasenames(name: String, size: String) {
	#expect(throws: DecodingError.self) {
		try JSONDecoder().decode(
			GameConfiguration.self, from: configurationJSON(executable: name, size: size))
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
