// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

struct UpdatesSettingsPage: View {
	@Bindable var settings: LauncherPreferencesController
	package let communication: LauncherCommunicationController
	package let installation: InstallationController
	package let lifecycle: LauncherLifecycleStore
	package let accentColor: Color
	let appVersion: String
	package let checkLauncherUpdates: () -> Void
	package let checkGameUpdates: () -> Void

	var body: some View {
		SettingsPage(
			title: "Updates",
			subtitle: "Keep the launcher and the game up to date",
			accentColor: accentColor
		) {
			SettingsPanel(
				title: "Automatic Checks",
				systemImage: "arrow.trianglehead.2.clockwise"
			) {
				UpdateSettingsRow(
					title: "Launcher",
					status: launcherStatusText,
					isEnabled: $settings.automaticallyChecksLauncherUpdates,
					isChecking: communication.isCheckingLauncherUpdates,
					isDisabled: !communication.canOpenLauncherUpdate,
					accentColor: accentColor,
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
					accentColor: accentColor,
					check: checkGameUpdates
				)
			}

			SettingsPanel(
				title: SettingsStrings.announcements, systemImage: "megaphone"
			) {
				SettingsActionRow(
					title: SettingsStrings.announcements,
					detail: "Show an occasional message from the project, once each."
				) {
					SettingsToggle(
						SettingsStrings.announcements,
						isOn: $settings.announcementsEnabled,
						accentColor: accentColor
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
		return "v\(appVersion)"
	}

	private var versionText: String {
		installation.installedVersion ?? installation.configuration?.gameLatestVersion ?? "—"
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
