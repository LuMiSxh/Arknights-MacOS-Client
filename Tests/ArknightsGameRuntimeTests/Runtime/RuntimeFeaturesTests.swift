// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import Testing

@testable import ArknightsGameRuntime

@Test
func runtimeFeaturesDecodeMissingFieldsAsFalse() throws {
	let features = try JSONDecoder().decode(
		RuntimeFeatures.self,
		from: Data(#"{"hardwareCursor":true}"#.utf8)
	)

	#expect(features.hardwareCursor)
	#expect(!features.metalFXSpatialUpscaling)
	#expect(!features.nativeFullscreenSpace)
}

@Test
func runtimeFeaturesConservativeDefaultsToFalse() {
	let features = RuntimeFeatures.conservative

	#expect(!features.hardwareCursor)
	#expect(!features.metalFXSpatialUpscaling)
	#expect(!features.nativeFullscreenSpace)
}

@Test(arguments: [true, false])
func runtimeFeaturesApplyHardwareCursorOverride(usesHardwareCursor: Bool) {
	let features = RuntimeFeatures(
		hardwareCursor: true, metalFXSpatialUpscaling: false, nativeFullscreenSpace: false)

	let environment = features.environmentOverrides(
		usesHardwareCursor: usesHardwareCursor, displayMode: .windowed)

	#expect(
		environment[AppConstants.Runtime.hardwareCursorEnvironmentKey]
			== (usesHardwareCursor ? "1" : nil))
}

@Test(arguments: [
	(GameDisplayMode.fullscreen, "1" as String?),
	(GameDisplayMode.windowed, nil as String?),
	(GameDisplayMode.borderlessWindow, nil as String?),
])
func runtimeFeaturesRequestNativeFullscreenSpaceOnlyForFullscreen(
	displayMode: GameDisplayMode,
	expected: String?
) {
	let features = RuntimeFeatures(
		hardwareCursor: false, metalFXSpatialUpscaling: false, nativeFullscreenSpace: true)

	let environment = features.environmentOverrides(
		usesHardwareCursor: false, displayMode: displayMode)

	#expect(
		environment[AppConstants.Runtime.nativeFullscreenSpaceEnvironmentKey] == expected)
}
