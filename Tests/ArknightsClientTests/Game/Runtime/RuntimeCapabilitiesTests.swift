// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

private let runtimeCapabilityManifest = Data(
	#"{"schemaVersion":1,"capabilities":{"dxmtMaximumFrameLatency":{"minimum":0,"maximum":3,"defaultValue":3},"hardwareCursor":true}}"#
		.utf8
)

@Test
func runtimeCapabilitiesGateOverridesAndClampToAdvertisedRange() throws {
	let capabilities = try RuntimeCapabilities.decode(from: runtimeCapabilityManifest)
	let overrides = capabilities.environmentOverrides(
		canaryFeaturesEnabled: true,
		maximumFrameLatency: 9,
		usesHardwareCursor: true
	)

	#expect(
		overrides == [
			"ARKNIGHTS_RUNTIME_DXMT_MAX_FRAME_LATENCY": "3",
			"ARKNIGHTS_RUNTIME_HARDWARE_CURSOR": "1",
		]
	)
	#expect(
		capabilities.environmentOverrides(
			canaryFeaturesEnabled: false,
			maximumFrameLatency: 0,
			usesHardwareCursor: true
		) == [:]
	)
	#expect(
		RuntimeCapabilities.conservative.environmentOverrides(
			canaryFeaturesEnabled: true,
			maximumFrameLatency: 1,
			usesHardwareCursor: true
		) == [:]
	)

	let legacyCursor = try RuntimeCapabilities.decode(
		from: Data(
			#"{"schemaVersion":1,"capabilities":{"dxmtMaximumFrameLatency":{"minimum":1,"maximum":3,"defaultValue":3},"hardwareCursor":false}}"#
				.utf8
		)
	)
	#expect(
		legacyCursor.environmentOverrides(
			canaryFeaturesEnabled: true,
			maximumFrameLatency: 0,
			usesHardwareCursor: true
		) == ["ARKNIGHTS_RUNTIME_DXMT_MAX_FRAME_LATENCY": "1"]
	)
}

@Test
func runtimeCapabilitiesRejectUnsupportedSchemaAndLatencyRanges() {
	let invalidManifests = [
		#"{"schemaVersion":2,"capabilities":{"dxmtMaximumFrameLatency":{"minimum":0,"maximum":3,"defaultValue":3},"hardwareCursor":true}}"#,
		#"{"schemaVersion":1,"capabilities":{"dxmtMaximumFrameLatency":{"minimum":0,"maximum":3,"defaultValue":3},"hardwareCursor":true},"future":true}"#,
		#"{"schemaVersion":1,"capabilities":{"dxmtMaximumFrameLatency":{"minimum":1,"maximum":3,"defaultValue":0},"hardwareCursor":true}}"#,
		#"{"schemaVersion":1,"capabilities":{"dxmtMaximumFrameLatency":{"minimum":0,"maximum":4,"defaultValue":3},"hardwareCursor":true}}"#,
	]

	for manifest in invalidManifests {
		#expect(throws: RuntimeCapabilityContractError.self) {
			try RuntimeCapabilities.decode(from: Data(manifest.utf8))
		}
	}
}

@Test
func runtimeCapabilityDiscoveryFailsClosedForMissingMalformedAndUnsafeFiles() throws {
	let fileManager = FileManager.default
	let root = fileManager.temporaryDirectory.appending(
		path: "runtime-capabilities-test-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
	defer { try? fileManager.removeItem(at: root) }

	let unconfigured = RuntimeCapabilities.discover(
		inRuntimeDirectory: root,
		manifestRelativePath: nil
	)
	#expect(unconfigured.capabilities == .conservative)
	#expect(unconfigured.diagnostic?.isEmpty == false)

	let unsafePath = RuntimeCapabilities.discover(
		inRuntimeDirectory: root,
		manifestRelativePath: "../runtime-capabilities.json"
	)
	#expect(unsafePath.capabilities == .conservative)
	#expect(unsafePath.diagnostic?.isEmpty == false)

	let relativePath = "runtime-capabilities.json"
	let manifestURL = root.appending(path: relativePath)
	try runtimeCapabilityManifest.write(to: manifestURL)
	let supported = RuntimeCapabilities.discover(
		inRuntimeDirectory: root,
		manifestRelativePath: relativePath
	)
	#expect(
		supported.capabilities == (try RuntimeCapabilities.decode(from: runtimeCapabilityManifest)))
	#expect(supported.diagnostic == nil)

	try fileManager.removeItem(at: manifestURL)
	let missing = RuntimeCapabilities.discover(
		inRuntimeDirectory: root,
		manifestRelativePath: relativePath
	)
	#expect(missing.capabilities == .conservative)
	#expect(missing.diagnostic?.isEmpty == false)

	try Data("{}".utf8).write(to: manifestURL)
	let malformed = RuntimeCapabilities.discover(
		inRuntimeDirectory: root,
		manifestRelativePath: relativePath
	)
	#expect(malformed.capabilities == .conservative)
	#expect(malformed.diagnostic?.isEmpty == false)

	try fileManager.removeItem(at: manifestURL)
	try fileManager.createSymbolicLink(
		at: manifestURL,
		withDestinationURL: root.appending(path: "missing-target.json")
	)
	let symbolicLink = RuntimeCapabilities.discover(
		inRuntimeDirectory: root,
		manifestRelativePath: relativePath
	)
	#expect(symbolicLink.capabilities == .conservative)
	#expect(symbolicLink.diagnostic?.isEmpty == false)

	try fileManager.removeItem(at: manifestURL)
	try Data(
		repeating: 97,
		count: AppConstants.Runtime.capabilityManifestMaximumBytes + 1
	).write(to: manifestURL)
	let oversized = RuntimeCapabilities.discover(
		inRuntimeDirectory: root,
		manifestRelativePath: relativePath
	)
	#expect(oversized.capabilities == .conservative)
	#expect(oversized.diagnostic?.contains("size limit") == true)
}
