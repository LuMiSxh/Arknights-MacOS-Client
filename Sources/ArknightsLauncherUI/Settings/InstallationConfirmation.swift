// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameRuntime
import SwiftUI

/// Destructive environment and settings actions that ask for confirmation first.
enum InstallationConfirmation {
	case rebuildEnvironment, resetSettings, deleteEnvironment, uninstallGame

	static let cancelTitle = "Cancel"
	static let rebuildDetail = "Next launch takes longer. Game files and logins stay."
	static let settingsResetDetail =
		"Puts every launcher setting back to its default. Game files, the install location, and the server stay."

	var title: String {
		switch self {
		case .rebuildEnvironment: "Rebuild the Game Environment?"
		case .resetSettings: "Reset All Launcher Settings?"
		case .deleteEnvironment: "Delete the Game Environment?"
		case .uninstallGame: "Uninstall Arknights?"
		}
	}

	var confirmTitle: String {
		switch self {
		case .rebuildEnvironment: "Rebuild Environment"
		case .resetSettings: "Reset Settings"
		case .deleteEnvironment: "Delete Environment"
		case .uninstallGame: "Move Game to Trash"
		}
	}

	var message: String {
		switch self {
		case .rebuildEnvironment: Self.rebuildDetail
		case .resetSettings: Self.settingsResetDetail
		case .deleteEnvironment:
			"This signs you out of every login saved in the sign-in window. Game files are untouched."
		case .uninstallGame: "The launcher stays installed."
		}
	}

	func perform(gameSession: GameSessionController, actions: any LauncherActions) {
		switch self {
		case .rebuildEnvironment: gameSession.forcePrefixMigration()
		case .resetSettings: actions.resetAllLauncherSettings()
		case .deleteEnvironment: gameSession.deleteWinePrefix()
		case .uninstallGame: actions.uninstallGame()
		}
	}
}

/// A danger row whose button opens the confirmation dialog for `confirming`.
struct InstallationDestructiveRow: View {
	let title: String
	let detail: String
	var help: String?
	let buttonTitle: String
	let systemImage: String
	let isDisabled: Bool
	let confirming: InstallationConfirmation
	@Binding var confirmation: InstallationConfirmation?

	var body: some View {
		SettingsActionRow(title: title, detail: detail, help: help) {
			CapsuleActionButton(
				title: buttonTitle,
				systemImage: systemImage,
				tone: .danger,
				presentation: .compact,
				role: .destructive
			) {
				confirmation = confirming
			}
			.disabled(isDisabled)
		}
	}
}

extension View {
	/// Shows the dialog for `confirmation` and runs its action when the user confirms.
	func installationConfirmation(
		_ confirmation: Binding<InstallationConfirmation?>,
		gameSession: GameSessionController,
		actions: any LauncherActions
	) -> some View {
		confirmationDialog(
			confirmation.wrappedValue?.title ?? "",
			isPresented: Binding(
				get: { confirmation.wrappedValue != nil },
				set: { isPresented in
					if !isPresented { confirmation.wrappedValue = nil }
				}
			),
			titleVisibility: .visible
		) {
			Button(confirmation.wrappedValue?.confirmTitle ?? "", role: .destructive) {
				if let request = confirmation.wrappedValue {
					request.perform(gameSession: gameSession, actions: actions)
				}
			}
			Button(InstallationConfirmation.cancelTitle, role: .cancel) {}
		} message: {
			Text(confirmation.wrappedValue?.message ?? "")
		}
	}
}
