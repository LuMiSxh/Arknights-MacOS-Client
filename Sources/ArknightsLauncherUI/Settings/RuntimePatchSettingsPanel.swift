// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

/// One switch per runtime patch. Turning a patch off asks first, because it can break the game.
struct RuntimePatchSettingsPanel: View {
	@Environment(\.launcherTheme) private var theme
	@Bindable var settings: LauncherPreferencesController
	let lane: RuntimeLane
	let isLocked: Bool
	@State private var pendingTurnOff: RuntimePatch?

	private var patches: [RuntimePatch] {
		RuntimePatch.allCases.filter { $0.lanes.contains(lane) }
	}

	var body: some View {
		SettingsPanel(title: "Runtime patches", tone: .warning) {
			if isLocked {
				Text("Quit the game to change these settings.")
					.font(.callout)
					.foregroundStyle(theme.textSecondary)
			}
			ForEach(patches, id: \.self) { patch in
				SettingsActionRow(title: patch.label, detail: patch.detail) {
					SettingsToggle(patch.label, isOn: binding(for: patch))
						.disabled(isLocked)
				}
			}
			SettingsActionRow(
				title: "Restore defaults",
				detail: "Turns every runtime patch back on."
			) {
				CapsuleActionButton(
					title: "Restore Defaults", systemImage: "arrow.counterclockwise",
					tone: .neutral, presentation: .compact
				) {
					settings.disabledRuntimePatches = []
				}
				.disabled(isLocked || settings.disabledRuntimePatches.isEmpty)
			}
		}
		.confirmationDialog(
			pendingTurnOff.map { "Turn Off \($0.label)?" } ?? "",
			isPresented: Binding(
				get: { pendingTurnOff != nil },
				set: { if !$0 { pendingTurnOff = nil } }
			),
			titleVisibility: .visible,
			presenting: pendingTurnOff
		) { patch in
			Button("Turn Off \(patch.label)", role: .destructive) {
				settings.disabledRuntimePatches.insert(patch)
			}
			Button("Cancel", role: .cancel) {}
		} message: { _ in
			Text(
				"The game may break or behave differently. To undo this, turn the patch back on here or choose Restore Defaults."
			)
		}
	}

	/// Turning a patch on needs no warning. Turning it off waits for the confirmation.
	private func binding(for patch: RuntimePatch) -> Binding<Bool> {
		Binding(
			get: { !settings.disabledRuntimePatches.contains(patch) },
			set: { isOn in
				if isOn {
					settings.disabledRuntimePatches.remove(patch)
				} else {
					pendingTurnOff = patch
				}
			}
		)
	}
}

extension RuntimePatch {
	fileprivate var label: String {
		switch self {
		case .aceImports: "Anti-cheat imports"
		case .appContainer: "Sandbox support"
		case .winsock: "Address sorting"
		case .menu: "Command-Q quit"
		case .audio: "Sound output follow"
		case .aceTiming: "Anti-cheat timing"
		case .aceDispatcher: "Anti-cheat lookup"
		case .aceRosetta: "Rosetta workarounds"
		case .eflags: "CPU flag carry"
		case .hybridThread: "Thread start fix"
		}
	}

	fileprivate var detail: String {
		switch self {
		case .aceImports:
			"Provides the Windows functions that the anti-cheat module imports. Turning it off can stop the game from starting."
		case .appContainer:
			"Provides the Windows sandbox functions that the sign-in window needs. Turning it off can break sign-in."
		case .winsock:
			"Adds a network call that the sign-in window uses to look up addresses. Turning it off can slow or break sign-in."
		case .menu:
			"Quits the game with Command-Q from the app menu. Off restores Wine’s Command-Option-Q."
		case .audio:
			"Moves game sound to the new output when you switch speakers or headphones."
		case .aceTiming:
			"Fixes a timing wait that the anti-cheat module uses. Turning it off can freeze or crash the game."
		case .aceDispatcher:
			"Answers a function lookup that the anti-cheat module makes at start. Turning it off can stop the game from starting."
		case .aceRosetta:
			"Handles CPU instructions that Rosetta lacks and the anti-cheat module uses. Turning it off can crash the game."
		case .eflags:
			"Keeps CPU status flags intact when the ARM64 runtime runs x64 code. Turning it off can cause crashes."
		case .hybridThread:
			"Repairs how threads start in mixed ARM64 and x64 code. Turning it off can cause crashes."
		}
	}
}
