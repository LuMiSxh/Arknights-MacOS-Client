// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameRuntime
import SwiftUI

struct RuntimeSettingsPage: View {
	@Environment(\.launcherTheme) var theme
	let settings: LauncherPreferencesController
	let gameSession: GameSessionController
	let runtimeSelection: RuntimeSelectionController
	let intelTranslation: IntelTranslationController
	let lifecycle: LauncherLifecycleStore
	let actions: any LauncherInstallationActions
	@State var pendingRuntimeLane: RuntimeLane?
	@State var isRemoveRuntimeConfirmationPresented = false
	@State var isRemoveSelectedRuntimeConfirmationPresented = false

	var body: some View {
		SettingsPage(
			title: "Runtime",
			subtitle: "Choose the runtime and manage its files"
		) {
			activeRuntimePanel
			maintenancePanel
			GameCompatibilitySettingsPanel(
				settings: settings,
				isLocked: gameSession.isGameActive
			)
			RuntimePatchSettingsPanel(
				settings: settings,
				lane: runtimeSelection.selectedLane,
				isLocked: gameSession.isGameActive
			)
			removeRuntimePanel
		}
		.confirmationDialog(
			runtimeSwitchDialogTitle,
			isPresented: Binding(
				get: { pendingRuntimeLane != nil },
				set: { if !$0 { pendingRuntimeLane = nil } }
			),
			titleVisibility: .visible
		) {
			Button(runtimeSwitchButtonTitle, action: confirmRuntimeSwitch)
			Button("Cancel", role: .cancel) { pendingRuntimeLane = nil }
		} message: {
			Text(runtimeSwitchMessage)
		}
		.confirmationDialog(
			"Remove the other runtime?",
			isPresented: $isRemoveRuntimeConfirmationPresented,
			titleVisibility: .visible
		) {
			Button("Remove", role: .destructive) {
				Task { _ = await actions.removeOtherRuntime() }
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text(
				"The other runtime's files are deleted. Its game environment stays on disk. You can download the runtime again later."
			)
		}
		.confirmationDialog(
			"Remove the \(runtimeSelection.selectedLane.shortLabel) runtime?",
			isPresented: $isRemoveSelectedRuntimeConfirmationPresented,
			titleVisibility: .visible
		) {
			Button("Remove", role: .destructive) {
				Task { _ = await actions.removeSelectedRuntime() }
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("The game environment stays. Set up the runtime again before you play.")
		}
	}
}
