// SPDX-License-Identifier: MPL-2.0

import Foundation

/// The architecture of the bundled Wine runtime. Each lane has its own Wine prefix, so a
/// runtime switch never changes the other lane's game environment.
package enum RuntimeLane: String, Sendable {
	case x86
	case arm

	/// The Wine prefix directory name for this lane.
	var prefixDirectoryName: String {
		switch self {
		case .x86: "Prefix"
		case .arm: "Prefix-ARM64"
		}
	}

	package var label: String {
		switch self {
		case .x86: "x86_64 via Rosetta"
		case .arm: "ARM64 native"
		}
	}

	/// The lane declared by the bundled `RUNTIME.json`. A SwiftPM run has no staged
	/// manifest. A manifest that exists but does not name a lane reports a diagnostic.
	static func bundled(resourceDirectory: URL?) -> (lane: RuntimeLane, diagnostic: String?) {
		guard let resourceDirectory else { return (.x86, nil) }
		let url = BundledResource.runtimeConfiguration.location(in: resourceDirectory)
		guard FileManager.default.fileExists(atPath: url.path) else { return (.x86, nil) }
		do {
			let manifest = try JSONDecoder().decode(
				BundledManifest.self, from: Data(contentsOf: url))
			guard
				let lane = declared(
					architecture: manifest.architecture,
					macDriver: manifest.interface?.macDriver,
					runtimeName: manifest.runtime?.name ?? ""
				)
			else {
				return (
					.x86,
					"Runtime manifest \(url.path) does not name a lane; using the x86 lane"
				)
			}
			return (lane, nil)
		} catch {
			return (
				.x86,
				"Could not read the runtime lane from \(url.path): \(error.localizedDescription)"
			)
		}
	}

	/// Resolve a lane from a runtime manifest. The explicit architecture wins over the
	/// Wine module path, which stays as a fallback for manifests that predate it.
	package static func declared(
		architecture: String?,
		macDriver: String?,
		runtimeName: String
	) -> RuntimeLane? {
		if let architecture, let lane = RuntimeLane(rawValue: architecture) {
			return lane
		}
		if let macDriver {
			if macDriver.contains("aarch64") { return .arm }
			if macDriver.contains("x86_64") { return .x86 }
		}
		if runtimeName.localizedCaseInsensitiveContains("aarch64") {
			return .arm
		}
		return nil
	}

	private struct BundledManifest: Decodable {
		struct Interface: Decodable {
			let macDriver: String?
		}
		struct Runtime: Decodable {
			let name: String?
		}
		let architecture: String?
		let interface: Interface?
		let runtime: Runtime?
	}
}
