// SPDX-License-Identifier: MPL-2.0

import SwiftUI

extension ContentView {
	@ViewBuilder
	func sheetContent(for destination: LauncherPresentationDestination) -> some View {
		switch destination {
		case .settings:
			LauncherSettingsView(
				settings: model.settings, customization: model.customization,
				communication: model.communication,
				installation: model.installation, gameSession: model.gameSession,
				runtimeSelection: model.runtimeSelection,
				lifecycle: model.lifecycle, reminders: model.reminders,
				screenshots: model.screenshots,
				storage: model.storage, storageOverview: model.storageOverview,
				playtimeStatistics: model.playtimeStatistics, presetCatalog: model.presetCatalog,
				launcherIconManager: model.launcherIconManager,
				branding: model.refreshController.branding,
				actions: model.actions,
				restartOnboarding: restartOnboarding,
				requestLauncherUpdateCheck: requestLauncherUpdateCheck,
				openProblemReport: { model.openProblemReport(source: .settings) },
				developerSimulation: developerSimulationBinding, windowSize: windowSize,
				selectedSection: $settingsSection
			)
		case .failure(let failure):
			LauncherFailureDetailView(
				failure: failure,
				perform: performRecoveryAction,
				isSavingDiagnostics: model.actions.isSavingDiagnostics,
				saveDiagnostics: {
					Task { await model.actions.saveDiagnostics() }
				},
				onDismiss: { presentation.dismissCurrent() }
			)
			.onDisappear(perform: failureDetailsDidDismiss)
		case .popup:
			if let popup = model.communication.popup {
				LauncherPopupView(
					popup: popup,
					dismiss: model.communication.dismissPopup,
					openAction: model.communication.openPopupAction)
			} else {
				EmptyView()
			}
		case .update: EmptyView()
		}
	}
}
