// SPDX-License-Identifier: MPL-2.0

import Foundation

enum RuntimeCapabilityContractError: LocalizedError, Sendable {
	case malformedManifest(String)
	case unsupportedSchema(Int)
	case invalidFrameLatencyRange
	case invalidManifestPath

	var errorDescription: String? {
		switch self {
		case .malformedManifest(let reason):
			"Capability manifest is malformed: \(reason)"
		case .unsupportedSchema(let version):
			"Capability manifest schema version \(version) is unsupported."
		case .invalidFrameLatencyRange:
			"Capability manifest frame latency range is invalid."
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
	struct FrameLatency: Decodable, Equatable, Sendable {
		let minimum: Int
		let maximum: Int
		let defaultValue: Int
	}

	static let conservative = RuntimeCapabilities(
		dxmtMaximumFrameLatency: nil,
		hardwareCursorSupported: false
	)

	let dxmtMaximumFrameLatency: FrameLatency?
	let hardwareCursorSupported: Bool

	private struct Manifest: Decodable {
		struct Capabilities: Decodable {
			let dxmtMaximumFrameLatency: FrameLatency
			let hardwareCursor: Bool
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
		guard manifest.schemaVersion == 1 else {
			throw RuntimeCapabilityContractError.unsupportedSchema(manifest.schemaVersion)
		}
		let latency = manifest.capabilities.dxmtMaximumFrameLatency
		guard (0...3).contains(latency.minimum),
			(1...3).contains(latency.maximum),
			latency.minimum <= latency.maximum,
			latency.defaultValue == 3,
			(latency.minimum...latency.maximum).contains(latency.defaultValue)
		else {
			throw RuntimeCapabilityContractError.invalidFrameLatencyRange
		}
		return RuntimeCapabilities(
			dxmtMaximumFrameLatency: latency,
			hardwareCursorSupported: manifest.capabilities.hardwareCursor
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

	func environmentOverrides(
		canaryFeaturesEnabled: Bool,
		maximumFrameLatency: Int,
		usesHardwareCursor: Bool
	) -> [String: String] {
		guard canaryFeaturesEnabled else { return [:] }
		var overrides: [String: String] = [:]
		if let latency = dxmtMaximumFrameLatency {
			overrides[AppConstants.Runtime.dxmtMaximumFrameLatencyEnvironmentKey] = String(
				min(max(maximumFrameLatency, latency.minimum), latency.maximum)
			)
		}
		if hardwareCursorSupported && usesHardwareCursor {
			overrides[AppConstants.Runtime.hardwareCursorEnvironmentKey] = "1"
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
			let capabilities = manifest["capabilities"] as? [String: Any],
			Set(capabilities.keys) == ["dxmtMaximumFrameLatency", "hardwareCursor"],
			let frameLatency = capabilities["dxmtMaximumFrameLatency"] as? [String: Any],
			Set(frameLatency.keys) == ["minimum", "maximum", "defaultValue"]
		else {
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
