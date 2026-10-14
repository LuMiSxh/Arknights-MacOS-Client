// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Testing

@testable import ArknightsGameInstallation
@testable import ArknightsGameRuntime

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
	(true, currentRuntimeCapabilities, "1"),
	(false, currentRuntimeCapabilities, nil as String?),
	(true, legacyRuntimeCapabilities, nil),
	(true, RuntimeCapabilities.conservative, nil),
])
@MainActor
func runtimeEnvironmentAppliesAdvertisedCapabilities(
	usesHardwareCursor: Bool,
	capabilities: RuntimeCapabilities,
	expectedHardwareCursor: String?
) {
	for region in GameRegion.allCases {
		let environment = GameSessionController.runtimeEnvironmentOverrides(
			for: region,
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
		#expect(environment["ARKNIGHTS_RUNTIME_DXMT_MAX_FRAME_LATENCY"] == nil)
		#expect(environment["ARKNIGHTS_RUNTIME_HARDWARE_CURSOR"] == expectedHardwareCursor)
	}
}
