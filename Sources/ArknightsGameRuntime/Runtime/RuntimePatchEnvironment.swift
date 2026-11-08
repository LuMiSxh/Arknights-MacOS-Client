// SPDX-License-Identifier: MPL-2.0

import ArknightsCore

/// Builds the `LMISXH_AKMOCL_*` compatibility environment for one launch.
struct RuntimePatchEnvironment {
	/// `lane` names the runtime that starts the game, but every gate is sent on both lanes and the
	/// ARM runtime ignores the x86-only ones.
	static func environment(
		for region: GameRegion,
		lane: RuntimeLane?,
		usesHardwareCursor: Bool,
		displayMode: GameDisplayMode,
		features: RuntimeFeatures = .conservative
	) -> [String: String] {
		let chinaCompatibility = region.usesEmbeddedLoginWindow ? "1" : "0"
		let hardwareCursor = features.hardwareCursor && usesHardwareCursor ? "1" : "0"
		let nativeFullscreen =
			features.usesNativeFullscreenSpace(for: displayMode) ? "1" : "0"
		return [
			AppConstants.Runtime.aceImportsEnvironmentKey: "1",
			AppConstants.Runtime.appContainerEnvironmentKey: "1",
			AppConstants.Runtime.winsockEnvironmentKey: "1",
			AppConstants.Runtime.cefCompatEnvironmentKey: chinaCompatibility,
			AppConstants.Runtime.cnCompatEnvironmentKey: chinaCompatibility,
			AppConstants.Runtime.fullscreenEnvironmentKey: nativeFullscreen,
			AppConstants.Runtime.hardwareCursorEnvironmentKey: hardwareCursor,
			AppConstants.Runtime.menuEnvironmentKey: "1",
			AppConstants.Runtime.audioEnvironmentKey: "1",
			AppConstants.Runtime.aceTimingEnvironmentKey: "1",
			AppConstants.Runtime.aceDispatcherEnvironmentKey: "1",
			AppConstants.Runtime.aceRosettaEnvironmentKey: "1",
		]
	}
}
