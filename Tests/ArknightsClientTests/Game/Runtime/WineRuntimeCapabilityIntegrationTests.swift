// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

private let currentRuntimeCapabilities = RuntimeCapabilities(
	dxmtMaximumFrameLatency: .init(minimum: 0, maximum: 3, defaultValue: 3),
	hardwareCursorSupported: true,
	metalFXSpatialUpscalingSupported: true
)
private let legacyRuntimeCapabilities = RuntimeCapabilities(
	dxmtMaximumFrameLatency: .init(minimum: 1, maximum: 3, defaultValue: 3),
	hardwareCursorSupported: false,
	metalFXSpatialUpscalingSupported: false
)

@Test(arguments: [
	(false, false, 0, currentRuntimeCapabilities, nil as String?, nil as String?),
	(false, false, 2, currentRuntimeCapabilities, nil, nil),
	(false, false, 3, currentRuntimeCapabilities, nil, nil),
	(false, true, 3, currentRuntimeCapabilities, nil, nil),
	(true, false, 0, currentRuntimeCapabilities, "0", nil),
	(true, false, 3, currentRuntimeCapabilities, "3", nil),
	(true, true, 3, currentRuntimeCapabilities, "3", "1"),
	(true, true, 0, RuntimeCapabilities.conservative, nil, nil),
	(true, true, 0, legacyRuntimeCapabilities, "1", nil),
])
@MainActor
func runtimeEnvironmentAppliesAdvertisedCanaryCapabilities(
	canaryFeaturesEnabled: Bool,
	usesHardwareCursor: Bool,
	maximumFrameLatency: Int,
	capabilities: RuntimeCapabilities,
	expectedFrameLatency: String?,
	expectedHardwareCursor: String?
) {
	for region in GameRegion.allCases {
		let environment = GameSessionController.runtimeEnvironmentOverrides(
			for: region,
			canaryFeaturesEnabled: canaryFeaturesEnabled,
			maximumFrameLatency: maximumFrameLatency,
			usesHardwareCursor: usesHardwareCursor,
			capabilities: capabilities
		)

		#expect(environment["ARKNIGHTS_RUNTIME_AUDIO_FOLLOW_DEFAULT_OUTPUT"] == "1")
		for key in [
			"ARKNIGHTS_RUNTIME_ACE_COMPACT", "ARKNIGHTS_RUNTIME_CN_COMPAT",
			"ARKNIGHTS_RUNTIME_CEF_COMPAT",
		] {
			#expect(environment[key] == region.runtimeEnvironmentOverrides[key])
		}
		#expect(environment["ARKNIGHTS_RUNTIME_PERFORMANCE"] == nil)
		#expect(environment["ARKNIGHTS_RUNTIME_DXMT_MAX_FRAME_LATENCY"] == expectedFrameLatency)
		#expect(environment["ARKNIGHTS_RUNTIME_HARDWARE_CURSOR"] == expectedHardwareCursor)
	}
}

@Test(arguments: [false, true])
func runtimeDiscoveryUsesTheSelectedBundlesCapabilityFile(configured: Bool) async throws {
	let fileManager = FileManager.default
	let root = fileManager.temporaryDirectory.appending(
		path: "runtime-bundle-contract-\(UUID().uuidString)", directoryHint: .isDirectory
	)
	defer { try? fileManager.removeItem(at: root) }
	let app = root.appending(path: "Fixture.app", directoryHint: .isDirectory)
	let contents = app.appending(path: "Contents", directoryHint: .isDirectory)
	let resources = contents.appending(path: "Resources", directoryHint: .isDirectory)
	let runtimeDirectory = resources.appending(path: "Runtime", directoryHint: .isDirectory)
	let bin = runtimeDirectory.appending(path: "bin", directoryHint: .isDirectory)
	try fileManager.createDirectory(at: bin, withIntermediateDirectories: true)
	let executable = bin.appending(path: "Arknights")
	try Data("fixture, never executed".utf8).write(to: executable)
	try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
	try PropertyListSerialization.data(
		fromPropertyList: [
			"CFBundleIdentifier": "test.runtime.capabilities",
			"CFBundleName": "Fixture",
			"CFBundlePackageType": "APPL",
		],
		format: .xml,
		options: 0
	).write(to: contents.appending(path: "Info.plist"))
	var configuration: [String: Any] = [
		"prefixRevision": 1,
		"runtime": ["sha256": String(repeating: "a", count: 64)],
	]
	if configured {
		configuration["interface"] = ["runtimeCapabilities": "selected-capabilities.json"]
	}
	try JSONSerialization.data(withJSONObject: configuration).write(
		to: resources.appending(path: "RUNTIME.json")
	)
	let manifest = Data(
		#"{"schemaVersion":1,"capabilities":{"dxmtMaximumFrameLatency":{"minimum":0,"maximum":3,"defaultValue":3},"hardwareCursor":true,"metalFXSpatialUpscaling":true}}"#
			.utf8
	)
	try manifest.write(to: runtimeDirectory.appending(path: "selected-capabilities.json"))
	try Data("{}".utf8).write(to: runtimeDirectory.appending(path: "runtime-capabilities.json"))
	let bundle = try #require(Bundle(url: app))
	let runtime = try WineRuntime.discover(
		bundle: bundle, compatibilityManager: GameCompatibilityManager()
	)
	let discovery = await runtime.discoverCapabilities()

	#expect(runtime.executableURL.standardizedFileURL == executable.standardizedFileURL)
	#expect(discovery.capabilities == (configured ? currentRuntimeCapabilities : .conservative))
	#expect((discovery.diagnostic == nil) == configured)
}
