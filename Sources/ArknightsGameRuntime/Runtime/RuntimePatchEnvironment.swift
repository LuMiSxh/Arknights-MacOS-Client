// SPDX-License-Identifier: MPL-2.0

import ArknightsCore

/// Builds the `LMISXH_AKMOCL_*` compatibility environment for one launch.
struct RuntimePatchEnvironment {
	/// The upstream gate variable for each patch the user can turn off.
	static func key(for patch: RuntimePatch) -> String {
		switch patch {
		case .aceImports: AppConstants.Runtime.aceImportsEnvironmentKey
		case .appContainer: AppConstants.Runtime.appContainerEnvironmentKey
		case .winsock: AppConstants.Runtime.winsockEnvironmentKey
		case .menu: AppConstants.Runtime.menuEnvironmentKey
		case .audio: AppConstants.Runtime.audioEnvironmentKey
		case .aceTiming: AppConstants.Runtime.aceTimingEnvironmentKey
		case .aceDispatcher: AppConstants.Runtime.aceDispatcherEnvironmentKey
		case .aceRosetta: AppConstants.Runtime.aceRosettaEnvironmentKey
		case .eflags: AppConstants.Runtime.eflagsEnvironmentKey
		case .hybridThread: AppConstants.Runtime.hybridThreadEnvironmentKey
		}
	}

	/// `lane` is the runtime that starts the game. A gate its build does not contain is not sent.
	/// A patch in `disabledPatches` gets `0`; every other gate is sent as `1`.
	static func environment(
		for region: GameRegion,
		lane: RuntimeLane,
		usesHardwareCursor: Bool,
		displayMode: GameDisplayMode,
		disabledPatches: Set<RuntimePatch> = [],
		features: RuntimeFeatures = .conservative
	) -> [String: String] {
		let chinaCompatibility = region.usesEmbeddedLoginWindow ? "1" : "0"
		let hardwareCursor = features.hardwareCursor && usesHardwareCursor ? "1" : "0"
		let nativeFullscreen =
			features.usesNativeFullscreenSpace(for: displayMode) ? "1" : "0"
		var environment = [
			AppConstants.Runtime.cefCompatEnvironmentKey: chinaCompatibility,
			AppConstants.Runtime.cnCompatEnvironmentKey: chinaCompatibility,
			AppConstants.Runtime.fullscreenEnvironmentKey: nativeFullscreen,
			AppConstants.Runtime.hardwareCursorEnvironmentKey: hardwareCursor,
		]
		for patch in RuntimePatch.allCases where patch.lanes.contains(lane) {
			environment[key(for: patch)] = disabledPatches.contains(patch) ? "0" : "1"
		}
		return environment
	}
}
