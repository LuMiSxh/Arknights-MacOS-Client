// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

struct UpdatesSettingsPage: View {
	@Bindable var settings: LauncherPreferencesController
	let communication: LauncherCommunicationController
	let installation: InstallationController
	let lifecycle: LauncherLifecycleStore
	let appVersion: String
	private static let announcementsTitle = "Announcements"
	let actions: any LauncherUpdateActions
	let checkLauncherUpdates: () -> Void

	var body: some View {
		SettingsPage(
			title: "Updates",
			subtitle: "Keep the launcher and the game up to date"
		) {
			SettingsPanel(
				title: "Automatic checks"
			) {
				UpdateSettingsRow(
					title: "Launcher",
					status: launcherStatusText,
					isEnabled: $settings.automaticallyChecksLauncherUpdates,
					isChecking: communication.isCheckingLauncherUpdates,
					isDisabled: !communication.canOpenLauncherUpdate,
					check: checkLauncherUpdates
				)
				SettingsHairline()
				UpdateSettingsRow(
					title: "Arknights",
					status: gameStatusText,
					isEnabled: $settings.automaticallyChecksGameUpdates,
					isChecking: lifecycle.state.refresh.isChecking,
					isDisabled: lifecycle.state.refresh.isChecking
						|| !lifecycle.canBeginExclusiveActivity,
					check: actions.checkGameUpdates
				)
			}

			SettingsPanel(
				title: Self.announcementsTitle
			) {
				SettingsActionRow(
					title: Self.announcementsTitle,
					detail: "Project news. Each message shows once."
				) {
					SettingsToggle(
						Self.announcementsTitle,
						isOn: $settings.announcementsEnabled,
					)
					.disabled(lifecycle.activity == .maintaining(.migratingStorage))
				}
			}
		}
	}

	private var launcherStatusText: String {
		if communication.isCheckingLauncherUpdates {
			return "Checking…"
		}
		if communication.launcherUpdateVersion != nil {
			return "Update available"
		}
		return "Version \(appVersion)"
	}

	private var versionText: String {
		(installation.installedVersion ?? installation.configuration?.gameLatestVersion).map {
			"Version \($0)"
		} ?? "—"
	}

	private var gameStatusText: String {
		if lifecycle.state.refresh.isChecking {
			return "Checking…"
		}
		if installation.isGameUpdateAvailable {
			return "Update available"
		}
		return versionText
	}
}
