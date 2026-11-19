// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

struct InstalledState: Codable, Sendable {
	let schemaVersion: Int
	let version: String
	let basis: String
	let source: String
	let installedAt: Date
	let files: [ManifestFile]?

	init(
		schemaVersion: Int = AppConstants.Game.installedStateSchemaVersion,
		version: String,
		basis: String,
		source: String,
		installedAt: Date,
		files: [ManifestFile]?
	) {
		self.schemaVersion = schemaVersion
		self.version = version
		self.basis = basis
		self.source = source
		self.installedAt = installedAt
		self.files = files
	}

	package init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		// Files written before the field existed are version 1.
		let schemaVersion =
			try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
		guard schemaVersion <= AppConstants.Game.installedStateSchemaVersion else {
			throw DecodingError.dataCorruptedError(
				forKey: .schemaVersion,
				in: container,
				debugDescription:
					"Installed state schema version \(schemaVersion) is newer than supported"
			)
		}
		self.schemaVersion = schemaVersion
		version = try container.decode(String.self, forKey: .version)
		basis = try container.decode(String.self, forKey: .basis)
		source = try container.decode(String.self, forKey: .source)
		installedAt = try container.decode(Date.self, forKey: .installedAt)
		files = try container.decodeIfPresent([ManifestFile].self, forKey: .files)
	}
}
