// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Foundation

enum RuntimeCapabilityContractError: LocalizedError, Sendable {
	case malformedManifest(String)
	case unsupportedSchema(Int)
	case invalidManifestPath

	var errorDescription: String? {
		switch self {
		case .malformedManifest(let reason):
			"Capability manifest is malformed: \(reason)"
		case .unsupportedSchema(let version):
			"Capability manifest schema version \(version) is unsupported."
		case .invalidManifestPath:
			"Capability manifest path must be a safe single filename."
		}
	}
}

struct RuntimeCapabilityDiscovery: Equatable, Sendable {
	let capabilities: RuntimeCapabilities
	let diagnostic: String?
}

struct RuntimeCapabilities: Equatable, Sendable {
	static let conservative = RuntimeCapabilities(
		hardwareCursorSupported: false,
		metalFXSpatialUpscalingSupported: false,
		nativeFullscreenSpaceSupported: false
	)

	let hardwareCursorSupported: Bool
	let metalFXSpatialUpscalingSupported: Bool
	let nativeFullscreenSpaceSupported: Bool

	private struct Manifest: Decodable {
		struct Capabilities: Decodable {
			let hardwareCursor: Bool
			/// Optional so runtimes published before 0.7.0 keep their other capabilities.
			let metalFXSpatialUpscaling: Bool?
			/// Optional so runtimes published before 0.8.0-rc3 keep their other capabilities.
			let nativeFullscreenSpace: Bool?
		}

		let schemaVersion: Int
		let capabilities: Capabilities
	}

	static func decode(from data: Data) throws -> RuntimeCapabilities {
		try validateManifestShape(in: data)
		let manifest: Manifest
		do {
			manifest = try JSONDecoder().decode(Manifest.self, from: data)
		} catch {
			throw RuntimeCapabilityContractError.malformedManifest(
				error.localizedDescription
			)
		}
		guard [1, 2].contains(manifest.schemaVersion) else {
			throw RuntimeCapabilityContractError.unsupportedSchema(manifest.schemaVersion)
		}
		return RuntimeCapabilities(
			hardwareCursorSupported: manifest.capabilities.hardwareCursor,
			metalFXSpatialUpscalingSupported: manifest.capabilities.metalFXSpatialUpscaling
				?? false,
			nativeFullscreenSpaceSupported: manifest.capabilities.nativeFullscreenSpace ?? false
		)
	}

	static func discover(
		inRuntimeDirectory directory: URL,
		manifestRelativePath: String?
	) -> RuntimeCapabilityDiscovery {
		guard let manifestRelativePath else {
			return fallback(
				"runtime configuration does not advertise a capability manifest"
			)
		}
		guard Self.isSafeManifestFilename(manifestRelativePath) else {
			return fallback(
				RuntimeCapabilityContractError.invalidManifestPath.localizedDescription
			)
		}
		let manifestURL = directory.appending(path: manifestRelativePath)
		do {
			let data = try BoundedFileReader.readRegularFile(
				at: manifestURL,
				maximumBytes: AppConstants.Runtime.capabilityManifestMaximumBytes
			)
			return RuntimeCapabilityDiscovery(
				capabilities: try decode(from: data),
				diagnostic: nil
			)
		} catch {
			return fallback(
				"Ignoring runtime capability manifest at \(manifestURL.path): \(Self.diagnostic(for: error))"
			)
		}
	}

	private static func isSafeManifestFilename(_ value: String) -> Bool {
		!value.isEmpty
			&& value != "."
			&& value != ".."
			&& !value.contains("/")
			&& !value.contains("\\")
			&& !value.utf8.contains(0)
	}

	private static func fallback(_ diagnostic: String) -> RuntimeCapabilityDiscovery {
		RuntimeCapabilityDiscovery(capabilities: .conservative, diagnostic: diagnostic)
	}

	/// Only fullscreen windows move into a native Space; windowed modes keep the normal window.
	func usesNativeFullscreenSpace(for displayMode: GameDisplayMode) -> Bool {
		nativeFullscreenSpaceSupported && displayMode == .fullscreen
	}

	func environmentOverrides(
		usesHardwareCursor: Bool,
		displayMode: GameDisplayMode
	) -> [String: String] {
		var overrides: [String: String] = [:]
		if hardwareCursorSupported && usesHardwareCursor {
			overrides[AppConstants.Runtime.hardwareCursorEnvironmentKey] = "1"
		}
		if usesNativeFullscreenSpace(for: displayMode) {
			overrides[AppConstants.Runtime.nativeFullscreenSpaceEnvironmentKey] = "1"
		}
		return overrides
	}

	private static func validateManifestShape(in data: Data) throws {
		let object: Any
		do {
			object = try JSONSerialization.jsonObject(with: data)
		} catch {
			throw RuntimeCapabilityContractError.malformedManifest(
				error.localizedDescription
			)
		}
		guard
			let manifest = object as? [String: Any],
			Set(manifest.keys) == ["schemaVersion", "capabilities"],
			let capabilities = manifest["capabilities"] as? [String: Any]
		else {
			throw RuntimeCapabilityContractError.malformedManifest(
				"the manifest contains missing or unknown fields"
			)
		}
		let capabilityKeys = Set(capabilities.keys).subtracting([
			"metalFXSpatialUpscaling", "nativeFullscreenSpace",
		])
		let hasExpectedShape: Bool
		switch manifest["schemaVersion"] as? Int {
		case 1?:
			// Schema 1 runtimes advertise a frame-latency range that the client ignores.
			let frameLatency = capabilities["dxmtMaximumFrameLatency"] as? [String: Any]
			let frameLatencyKeys = frameLatency.map { Set($0.keys) }
			hasExpectedShape =
				capabilityKeys == ["dxmtMaximumFrameLatency", "hardwareCursor"]
				&& frameLatencyKeys == Set(["minimum", "maximum", "defaultValue"])
		case 2?:
			hasExpectedShape = capabilityKeys == ["hardwareCursor"]
		default:
			// decode(from:) rejects unsupported schema versions.
			hasExpectedShape = true
		}
		guard hasExpectedShape else {
			throw RuntimeCapabilityContractError.malformedManifest(
				"the manifest contains missing or unknown fields"
			)
		}
	}

	private static func diagnostic(for error: Error) -> String {
		guard let error = error as? BoundedFileReadError else {
			return error.localizedDescription
		}
		switch error {
		case .invalidMaximum:
			return "the configured file-size limit is invalid"
		case .notRegularFile:
			return "the manifest is not a regular file"
		case .tooLarge(_, let maximumBytes):
			return "the manifest exceeds the \(maximumBytes)-byte size limit"
		}
	}
}
