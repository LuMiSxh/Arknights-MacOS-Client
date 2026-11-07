// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

/// One installed runtime's `RUNTIME.json`. The same decoder reads the manifest that the
/// installer writes and the manifest that diagnostics collects. The lane is explicit: a missing
/// or unknown `architecture` is rejected, never inferred from `macDriver` or the runtime name.
package struct RuntimeManifest: Codable, Sendable {
	package struct Runtime: Codable, Sendable {
		package let name: String
		package let version: String?
		package let sha256: String
		package let sizeBytes: Int?
	}

	package struct Interface: Codable, Sendable, Equatable {
		package struct Archive: Codable, Sendable, Equatable {
			package let wineDirectory: String
			package let dxmtDirectory: String
		}

		package struct Launcher: Codable, Sendable, Equatable {
			package let path: String
			package let target: String
		}

		package struct DXMT: Codable, Sendable, Equatable {
			package let payloadDirectory: String
			package let destinations: [String: String]
			package let libraries: [String]
		}

		package let archive: Archive
		package let executables: [String]
		package let features: RuntimeFeatures
		package let requiredFiles: [String]
		package let macDriver: String
		package let launcher: Launcher
		package let dxmt: DXMT

		/// The Developer ID loader bundle inside the prepared runtime tree.
		package var loaderPath: String? {
			let components = macDriver.split(separator: "/")
			guard components.count > 1 else { return nil }
			return components.dropLast().joined(separator: "/") + "/wine.app"
		}

		/// The DXMT files that must exist for the declared destinations and libraries.
		package var dxmtPayloadFiles: [String] {
			dxmt.destinations.keys.sorted().flatMap { architecture in
				dxmt.libraries.map {
					"\(dxmt.payloadDirectory)/\(architecture)/\($0)"
				}
			}
		}
	}

	package struct Components: Codable, Sendable, Equatable {
		package let wine: String?
		package let dxmt: String?
		package let moltenvk: String?
	}

	package struct Provenance: Codable, Sendable, Equatable {
		package let wineCommit: String?
		package let dxmtCommit: String?
	}

	package let prefixRevision: Int
	package let architecture: RuntimeLane
	package let runtime: Runtime
	package let interface: Interface
	package let components: Components?
	package let provenance: Provenance?

	package var revision: String {
		"\(runtime.sha256)-prefix-\(prefixRevision)"
	}

	package init(
		prefixRevision: Int,
		architecture: RuntimeLane,
		runtime: Runtime,
		interface: Interface,
		components: Components?,
		provenance: Provenance?
	) {
		self.prefixRevision = prefixRevision
		self.architecture = architecture
		self.runtime = runtime
		self.interface = interface
		self.components = components
		self.provenance = provenance
	}

	private enum CodingKeys: String, CodingKey {
		case prefixRevision
		case architecture
		case runtime
		case interface
		case components
		case provenance
	}

	package init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let declared = try container.decode(String.self, forKey: .architecture)
		guard let architecture = RuntimeLane(rawValue: declared) else {
			throw DecodingError.dataCorruptedError(
				forKey: .architecture,
				in: container,
				debugDescription: "architecture must be x86 or arm, not \(declared)"
			)
		}
		self.architecture = architecture
		prefixRevision = try container.decode(Int.self, forKey: .prefixRevision)
		runtime = try container.decode(Runtime.self, forKey: .runtime)
		interface = try container.decode(Interface.self, forKey: .interface)
		components = try container.decodeIfPresent(Components.self, forKey: .components)
		provenance = try container.decodeIfPresent(Provenance.self, forKey: .provenance)
	}
}
