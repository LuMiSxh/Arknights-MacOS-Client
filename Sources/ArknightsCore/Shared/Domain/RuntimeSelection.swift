// SPDX-License-Identifier: MPL-2.0

import Foundation

/// The persisted runtime document: the selected lane and the installed version of each lane.
/// The installer and remover write it, so no directory scan decides what is installed.
package struct RuntimeSelection: Codable, Equatable, Sendable {
	package var selected: RuntimeLane
	package var installedVersions: [RuntimeLane: String]

	package init(
		selected: RuntimeLane = .x86,
		installedVersions: [RuntimeLane: String] = [:]
	) {
		self.selected = selected
		self.installedVersions = installedVersions
	}

	package func installedVersion(for lane: RuntimeLane) -> String? {
		installedVersions[lane]
	}

	// `installed` is a JSON object keyed by lane name. A synthesized `[RuntimeLane: String]`
	// would encode as a flat key/value array.
	private enum CodingKeys: String, CodingKey {
		case selected
		case installed
	}

	package init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		selected = try container.decode(RuntimeLane.self, forKey: .selected)
		let installed =
			try container.decodeIfPresent([String: String].self, forKey: .installed) ?? [:]
		installedVersions = Dictionary(
			uniqueKeysWithValues: installed.compactMap { name, version in
				RuntimeLane(rawValue: name).map { ($0, version) }
			})
	}

	package func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(selected, forKey: .selected)
		if !installedVersions.isEmpty {
			try container.encode(
				Dictionary(
					uniqueKeysWithValues: installedVersions.map {
						($0.key.rawValue, $0.value)
					}),
				forKey: .installed)
		}
	}
}
