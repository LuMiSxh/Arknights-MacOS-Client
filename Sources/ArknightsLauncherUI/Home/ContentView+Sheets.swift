// SPDX-License-Identifier: MPL-2.0

import SwiftUI

extension ContentView {
	@ViewBuilder
	func sheetContent(for destination: LauncherPresentationDestination) -> some View {
		switch destination {
		case .settings:
			LauncherSettingsView(
				dependencies: model.settingsDependencies,
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
