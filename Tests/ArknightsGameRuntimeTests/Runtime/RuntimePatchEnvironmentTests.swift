// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Testing

@testable import ArknightsGameRuntime

private let patchGateKeys = [
	"LMISXH_AKMOCL_ACE_IMPORTS",
	"LMISXH_AKMOCL_APPCONTAINER",
	"LMISXH_AKMOCL_WINSOCK",
	"LMISXH_AKMOCL_CEF",
	"LMISXH_AKMOCL_CN",
	"LMISXH_AKMOCL_FULLSCREEN",
	"LMISXH_AKMOCL_CURSOR",
	"LMISXH_AKMOCL_MENU",
	"LMISXH_AKMOCL_AUDIO",
	"LMISXH_AKMOCL_ACE_TIMING",
	"LMISXH_AKMOCL_ACE_DISPATCHER",
	"LMISXH_AKMOCL_ACE_ROSETTA",
]

struct PatchLaunchState: Sendable, CustomTestStringConvertible {
	let region: GameRegion
	let lane: RuntimeLane
	let features: RuntimeFeatures
	let usesHardwareCursor: Bool
	let displayMode: GameDisplayMode
	let expectedHardwareCursor: String
	let expectedFullscreen: String

	var testDescription: String {
		"\(region.rawValue)-\(lane.rawValue)-\(expectedHardwareCursor)-\(expectedFullscreen)"
	}
}

private let patchFeatureStates: [(RuntimeFeatures, Bool, GameDisplayMode, String, String)] = [
	(
		.init(hardwareCursor: true, metalFXSpatialUpscaling: true, nativeFullscreenSpace: true),
		true, .fullscreen, "1", "1"
	),
	(
		.init(hardwareCursor: true, metalFXSpatialUpscaling: true, nativeFullscreenSpace: true),
		false, .windowed, "0", "0"
	),
	(
		.init(hardwareCursor: false, metalFXSpatialUpscaling: true, nativeFullscreenSpace: true),
		true, .fullscreen, "0", "1"
	),
	(
		.init(hardwareCursor: true, metalFXSpatialUpscaling: true, nativeFullscreenSpace: false),
		true, .fullscreen, "1", "0"
	),
]

private let patchLaunchStates: [PatchLaunchState] =
	GameRegion.allCases.flatMap { region in
		RuntimeLane.allCases.flatMap { lane in
			patchFeatureStates.map { state in
				PatchLaunchState(
					region: region,
					lane: lane,
					features: state.0,
					usesHardwareCursor: state.1,
					displayMode: state.2,
					expectedHardwareCursor: state.3,
					expectedFullscreen: state.4
				)
			}
		}
	}

@Test(arguments: patchLaunchStates)
func runtimePatchEnvironmentSendsEveryGateWithAnExplicitValue(
	_ state: PatchLaunchState
) {
	let environment = RuntimePatchEnvironment.environment(
		for: state.region,
		lane: state.lane,
		usesHardwareCursor: state.usesHardwareCursor,
		displayMode: state.displayMode,
		features: state.features
	)

	#expect(Set(environment.keys) == Set(patchGateKeys))
	for key in patchGateKeys {
		#expect(environment[key] == "0" || environment[key] == "1")
	}

	let chinaCompatibility =
		state.region == .china || state.region == .chinaBilibili ? "1" : "0"
	#expect(environment["LMISXH_AKMOCL_CEF"] == chinaCompatibility)
	#expect(environment["LMISXH_AKMOCL_CN"] == chinaCompatibility)
	#expect(
		environment["LMISXH_AKMOCL_CURSOR"] == state.expectedHardwareCursor)
	#expect(
		environment["LMISXH_AKMOCL_FULLSCREEN"] == state.expectedFullscreen)

	for key in [
		"LMISXH_AKMOCL_ACE_IMPORTS",
		"LMISXH_AKMOCL_APPCONTAINER",
		"LMISXH_AKMOCL_WINSOCK",
		"LMISXH_AKMOCL_MENU",
		"LMISXH_AKMOCL_AUDIO",
		"LMISXH_AKMOCL_ACE_TIMING",
		"LMISXH_AKMOCL_ACE_DISPATCHER",
		"LMISXH_AKMOCL_ACE_ROSETTA",
	] {
		#expect(environment[key] == "1")
	}
}
