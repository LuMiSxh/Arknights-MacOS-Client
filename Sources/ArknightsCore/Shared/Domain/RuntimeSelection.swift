// SPDX-License-Identifier: MPL-2.0

import Foundation

/// The persisted runtime document: an optional lane override and the installed version of each
/// lane. The installer and remover write it, so no directory scan decides what is installed.
///
/// The launcher chooses the lane. Only the user's override, set in the Danger zone, can change
/// that choice, and only while the OS allows it.
package struct RuntimeSelection: Codable, Equatable, Sendable {
	package var override: RuntimeLane?
	package var installedVersions: [RuntimeLane: String]
	/// The effective lane at the last save. It exists for diagnostics and older builds and is never
	/// read as a choice: a lane that a previous launcher persisted here must not pin the user.
	package private(set) var recordedLane: RuntimeLane?

	package init(
		override: RuntimeLane? = nil,
		installedVersions: [RuntimeLane: String] = [:]
	) {
		self.override = override
		self.installedVersions = installedVersions
	}

	/// The override, or nil when none is set or the OS no longer allows it.
	package func validOverride(access: RuntimeAccess) -> RuntimeLane? {
		override.flatMap { access.allows($0) ? $0 : nil }
	}

	package func effectiveLane(access: RuntimeAccess) -> RuntimeLane {
		validOverride(access: access) ?? access.defaultLane
	}

	/// Returns a copy whose recorded lane is the effective lane under `access`.
	package func recording(access: RuntimeAccess) -> RuntimeSelection {
		var copy = self
		copy.recordedLane = effectiveLane(access: access)
		return copy
	}

	package func installedVersion(for lane: RuntimeLane) -> String? {
		installedVersions[lane]
	}

	// `installed` is a JSON object keyed by lane name. A synthesized `[RuntimeLane: String]`
	// would encode as a flat key/value array.
	private enum CodingKeys: String, CodingKey {
		case selected
		case override
		case installed
	}

	package init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		recordedLane = try container.decodeIfPresent(RuntimeLane.self, forKey: .selected)
		override = try container.decodeIfPresent(RuntimeLane.self, forKey: .override)
		let installed =
			try container.decodeIfPresent([String: String].self, forKey: .installed) ?? [:]
		installedVersions = Dictionary(
			uniqueKeysWithValues: installed.compactMap { name, version in
				RuntimeLane(rawValue: name).map { ($0, version) }
			})
	}

	package func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encodeIfPresent(recordedLane, forKey: .selected)
		try container.encodeIfPresent(override, forKey: .override)
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
