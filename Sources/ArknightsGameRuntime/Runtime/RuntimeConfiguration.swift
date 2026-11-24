// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

enum RuntimeConfigurationError: Error, Equatable, Sendable {
	case unsupportedSchema(Int)
	case missingLane(RuntimeLane)
	case invalidPin(lane: RuntimeLane, reason: String)
}

/// A downloadable runtime file that is verified by size and SHA-256.
struct RuntimeAsset: Sendable, Equatable {
	let url: URL
	let sha256: String
	let sizeBytes: Int

	/// The resumable download file inside a lane's downloads directory.
	func partialFile(in directory: URL) -> URL {
		directory.appending(path: "\(sha256).part")
	}
}

/// A pinned delta that upgrades exactly the installed version `from` to the pinned version.
struct PinnedRuntimeDelta: Sendable, Equatable {
	let from: String
	let asset: RuntimeAsset
}

/// The pinned runtime archive for one lane, taken from `runtime.json`.
package struct PinnedRuntime: Sendable {
	package let lane: RuntimeLane
	package let name: String
	package let version: String
	package let url: URL?
	package let sha256: String
	package let sizeBytes: Int
	package let minimumMacOS: OperatingSystemVersion
	package let prefixRevision: Int
	package let interface: RuntimeManifest.Interface
	package let components: RuntimeManifest.Components?
	package let provenance: RuntimeManifest.Provenance?
	let deltas: [PinnedRuntimeDelta]

	package var features: RuntimeFeatures { interface.features }

	/// Whether the pin names a complete archive. An empty URL, checksum, or size means the
	/// release task has not published this lane yet.
	package var isAvailable: Bool {
		url != nil && !sha256.isEmpty && sizeBytes > 0
	}

	/// The full archive, or nil while the lane is unpublished.
	var archiveAsset: RuntimeAsset? {
		guard isAvailable, let url else { return nil }
		return RuntimeAsset(url: url, sha256: sha256, sizeBytes: sizeBytes)
	}

	/// The manifest written beside the installed runtime tree.
	var manifest: RuntimeManifest {
		RuntimeManifest(
			prefixRevision: prefixRevision,
			architecture: lane,
			runtime: RuntimeManifest.Runtime(
				name: name,
				version: version,
				sha256: sha256,
				sizeBytes: sizeBytes
			),
			interface: interface,
			components: components,
			provenance: provenance
		)
	}
}

/// The schema 4 runtime configuration: one pinned archive, its deltas, and an interface per lane.
package struct RuntimeConfiguration: Decodable, Sendable {
	struct Delta: Decodable {
		let from: String
		let url: String
		let sha256: String
		let sizeBytes: Int
	}

	struct Archive: Decodable {
		let name: String
		let version: String
		let url: String
		let sha256: String
		let sizeBytes: Int
		let deltas: [Delta]

		private enum CodingKeys: String, CodingKey {
			case name, version, url, sha256, sizeBytes, deltas
		}

		init(from decoder: any Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			name = try container.decode(String.self, forKey: .name)
			version = try container.decode(String.self, forKey: .version)
			url = try container.decode(String.self, forKey: .url)
			sha256 = try container.decode(String.self, forKey: .sha256)
			sizeBytes = try container.decode(Int.self, forKey: .sizeBytes)
			deltas = try container.decodeIfPresent([Delta].self, forKey: .deltas) ?? []
		}
	}

	struct Lane: Decodable {
		let minimumMacOS: String
		let prefixRevision: Int
		let runtime: Archive
		let interface: RuntimeManifest.Interface
		let components: RuntimeManifest.Components?
		let provenance: RuntimeManifest.Provenance?
	}

	struct Lanes: Decodable {
		let x86: Lane?
		let arm: Lane?

		func lane(_ lane: RuntimeLane) -> Lane? {
			switch lane {
			case .x86: x86
			case .arm: arm
			}
		}
	}

	private static let supportedSchemaVersion = 4

	let schemaVersion: Int
	let lanes: Lanes

	package static func bundled() throws -> RuntimeConfiguration {
		let data = try BundledResource.runtimeConfiguration.data()
		return try JSONDecoder().decode(Self.self, from: data)
	}

	package func pinnedRuntime(for requestedLane: RuntimeLane) throws -> PinnedRuntime {
		guard schemaVersion == Self.supportedSchemaVersion else {
			throw RuntimeConfigurationError.unsupportedSchema(schemaVersion)
		}
		guard let lane = lanes.lane(requestedLane) else {
			throw RuntimeConfigurationError.missingLane(requestedLane)
		}
		guard let minimumMacOS = Self.parseMacOSVersion(lane.minimumMacOS) else {
			throw RuntimeConfigurationError.invalidPin(
				lane: requestedLane, reason: "invalid minimumMacOS \(lane.minimumMacOS)")
		}
		guard lane.prefixRevision > 0 else {
			throw RuntimeConfigurationError.invalidPin(
				lane: requestedLane, reason: "prefixRevision must be greater than zero")
		}
		try Self.validatePin(lane.runtime, lane: requestedLane)
		try Self.validateInterface(lane.interface, lane: requestedLane)
		let url = lane.runtime.url.isEmpty ? nil : Self.httpsURL(lane.runtime.url)
		if !lane.runtime.url.isEmpty, url == nil {
			throw RuntimeConfigurationError.invalidPin(
				lane: requestedLane, reason: "runtime.url must use HTTPS")
		}
		return PinnedRuntime(
			lane: requestedLane,
			name: lane.runtime.name,
			version: lane.runtime.version,
			url: url,
			sha256: lane.runtime.sha256,
			sizeBytes: lane.runtime.sizeBytes,
			minimumMacOS: minimumMacOS,
			prefixRevision: lane.prefixRevision,
			interface: lane.interface,
			components: lane.components,
			provenance: lane.provenance,
			deltas: try lane.runtime.deltas.map { try Self.pinnedDelta($0, lane: requestedLane) }
		)
	}

	// MARK: - Validation

	private static func validatePin(_ archive: Archive, lane: RuntimeLane) throws {
		guard !archive.name.isEmpty else {
			throw RuntimeConfigurationError.invalidPin(
				lane: lane, reason: "runtime.name is empty")
		}
		guard isSafePathComponent(archive.version) else {
			throw RuntimeConfigurationError.invalidPin(
				lane: lane, reason: "runtime.version is not a path component")
		}
		if !archive.sha256.isEmpty, !isSHA256(archive.sha256) {
			throw RuntimeConfigurationError.invalidPin(
				lane: lane, reason: "runtime.sha256 must be 64 lowercase hex characters")
		}
		guard archive.sizeBytes >= 0 else {
			throw RuntimeConfigurationError.invalidPin(
				lane: lane, reason: "runtime.sizeBytes must not be negative")
		}
	}

	private static func pinnedDelta(
		_ delta: Delta, lane: RuntimeLane
	) throws -> PinnedRuntimeDelta {
		guard isSafePathComponent(delta.from), isSHA256(delta.sha256), delta.sizeBytes > 0,
			let url = httpsURL(delta.url)
		else {
			throw RuntimeConfigurationError.invalidPin(
				lane: lane, reason: "runtime.deltas has an invalid entry for \(delta.from)")
		}
		return PinnedRuntimeDelta(
			from: delta.from,
			asset: RuntimeAsset(url: url, sha256: delta.sha256, sizeBytes: delta.sizeBytes))
	}

	private static func validateInterface(
		_ interface: RuntimeManifest.Interface,
		lane: RuntimeLane
	) throws {
		let paths =
			[
				interface.macDriver, interface.launcher.path,
				interface.dxmt.payloadDirectory,
			] + interface.executables + interface.requiredFiles
		guard paths.allSatisfy(isSafeRelativePath) else {
			throw RuntimeConfigurationError.invalidPin(
				lane: lane, reason: "interface contains an unsafe path")
		}
		guard isSafePathComponent(interface.launcher.target) else {
			throw RuntimeConfigurationError.invalidPin(
				lane: lane, reason: "launcher.target must be one path component")
		}
		guard !interface.executables.isEmpty else {
			throw RuntimeConfigurationError.invalidPin(
				lane: lane, reason: "interface.executables must not be empty")
		}
		guard !interface.dxmt.destinations.isEmpty, !interface.dxmt.libraries.isEmpty else {
			throw RuntimeConfigurationError.invalidPin(
				lane: lane, reason: "interface.dxmt must declare destinations and libraries")
		}
		guard
			interface.dxmt.destinations.allSatisfy({
				isSafePathComponent($0.key) && isSafePathComponent($0.value)
			})
		else {
			throw RuntimeConfigurationError.invalidPin(
				lane: lane, reason: "dxmt.destinations must be safe path components")
		}
		guard interface.dxmt.libraries.allSatisfy(isSafePathComponent) else {
			throw RuntimeConfigurationError.invalidPin(
				lane: lane, reason: "dxmt.libraries must be file names")
		}
	}

	static func httpsURL(_ value: String) -> URL? {
		guard let url = URL(string: value), url.scheme == "https",
			let host = url.host, !host.isEmpty
		else {
			return nil
		}
		return url
	}

	static func isSHA256(_ value: String) -> Bool {
		value.utf8.count == 64
			&& value.utf8.allSatisfy {
				($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102)
			}
	}

	static func isSafePathComponent(_ value: String) -> Bool {
		!value.isEmpty
			&& value != "."
			&& value != ".."
			&& !value.contains("/")
			&& !value.contains("\\")
			&& !value.utf8.contains(0)
	}

	static func isSafeRelativePath(_ value: String) -> Bool {
		guard !value.isEmpty, !value.hasPrefix("/"), !value.contains("\\"),
			!value.utf8.contains(0)
		else {
			return false
		}
		let components = value.split(separator: "/", omittingEmptySubsequences: false)
		guard components.allSatisfy({ $0 != "." && $0 != ".." && !$0.isEmpty }) else {
			return false
		}
		if let first = components.first, first.count >= 2,
			first[first.index(after: first.startIndex)] == ":"
		{
			return false
		}
		return true
	}

	static func parseMacOSVersion(_ value: String) -> OperatingSystemVersion? {
		let components = value.split(separator: ".", omittingEmptySubsequences: false)
		guard (2...3).contains(components.count) else { return nil }
		let numbers = components.compactMap { Int($0) }
		guard numbers.count == components.count, numbers.allSatisfy({ $0 >= 0 }) else {
			return nil
		}
		return OperatingSystemVersion(
			majorVersion: numbers[0],
			minorVersion: numbers[1],
			patchVersion: numbers.count == 3 ? numbers[2] : 0
		)
	}
}
