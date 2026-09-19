// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct UpdatesSettingsPage: View {
	@Bindable var settings: LauncherPreferencesController
	let communication: LauncherCommunicationController
	let installation: InstallationController
	let lifecycle: LauncherLifecycleStore
	let accentColor: Color
	let appVersion: String
	let checkLauncherUpdates: () -> Void
	let checkGameUpdates: () -> Void

	var body: some View {
		SettingsPage(
			title: SettingsStrings.updatesTitle,
			subtitle: SettingsStrings.updatesSubtitle,
			accentColor: accentColor
		) {
			SettingsPanel(
				title: SettingsStrings.automaticChecks,
				systemImage: "arrow.trianglehead.2.clockwise"
			) {
				UpdateSettingsRow(
					title: SettingsStrings.launcher,
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
					isChecking: lifecycle.refresh.isChecking,
					isDisabled: lifecycle.refresh.isChecking
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
					detail: SettingsStrings.announcementsDetail
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
			return SettingsStrings.checking
		}
		if communication.launcherUpdateVersion != nil {
			return SettingsStrings.updateAvailable
		}
		return "v\(appVersion)"
	}

	private var versionText: String {
		installation.installedVersion ?? installation.configuration?.gameLatestVersion ?? "—"
	}

	private var gameStatusText: String {
		if lifecycle.refresh.isChecking {
			return SettingsStrings.checking
		}
		if installation.isGameUpdateAvailable {
			return SettingsStrings.updateAvailable
		}
		return versionText
	}
}
