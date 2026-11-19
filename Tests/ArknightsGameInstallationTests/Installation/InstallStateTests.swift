// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsGameInstallation

@Test
func installedStateDecodingAcceptsLegacyFilesAndRejectsNewerSchemas() throws {
	let decoder = JSONDecoder()
	decoder.dateDecodingStrategy = .iso8601
	func decode(schemaVersion: String) throws -> InstalledState {
		try decoder.decode(
			InstalledState.self,
			from: Data(
				"""
				{"version":"1.0.0","basis":"manifest.json","source":"official",
				"installedAt":"2026-01-01T00:00:00Z"\(schemaVersion)}
				""".utf8
			)
		)
	}

	let legacy = try decode(schemaVersion: "")
	#expect(legacy.schemaVersion == 1)
	#expect(legacy.files == nil)

	#expect(throws: DecodingError.self) {
		try decode(schemaVersion: ",\"schemaVersion\":2")
	}
}
