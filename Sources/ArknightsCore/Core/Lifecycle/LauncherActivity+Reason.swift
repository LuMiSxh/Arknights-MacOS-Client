// SPDX-License-Identifier: MPL-2.0

extension LauncherActivity {
	/// The one activity-to-reason mapping for locked settings, or `nil` while idle.
	/// Every disabled control, banner, and footnote takes its reason from here.
	package var lockReason: String? {
		switch self {
		case .idle:
			nil
		case .maintaining(let activity):
			switch activity {
			case .clearingCache: "Wait for the cache to clear."
			case .deletingWinePrefix: "Wait for the game environment reset to finish."
			case .uninstalling: "Wait for the uninstall to finish."
			case .removingRuntime: "Wait for the runtime removal to finish."
			case .updatingLauncher: "Wait for the launcher update to finish."
			case .migratingStorage: "Wait for the storage move to finish."
			}
		case .installing:
			"Wait for the download to finish."
		case .preparingGame, .launchingGame:
			"Wait for the game to start to change these settings."
		case .runningGame:
			"Quit the game to change these settings."
		case .stoppingGame:
			"Wait for the game to quit to change these settings."
		}
	}
}
