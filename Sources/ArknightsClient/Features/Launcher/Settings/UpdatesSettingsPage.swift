// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct UpdatesSettingsPage: View {
	@Bindable var settings: LauncherPreferencesController
	let communication: LauncherCommunicationController
	let installation: InstallationController
	let accentColor: Color
	let appVersion: String
	let checkLauncherUpdates: () -> Void
	let checkGameUpdates: () -> Void

	var body: some View {
		SettingsPage(
			title: L10n.string(SettingsStrings.updatesTitle),
			subtitle: L10n.string(SettingsStrings.updatesSubtitle),
			accentColor: accentColor
		) {
			SettingsPanel(
				title: L10n.string(SettingsStrings.automaticChecks),
				systemImage: "arrow.trianglehead.2.clockwise"
			) {
				UpdateSettingsRow(
					title: "Launcher",
					status: launcherStatusText,
					isEnabled: $settings.automaticallyChecksLauncherUpdates,
					isChecking: communication.isCheckingLauncherUpdates,
					accentColor: accentColor,
					check: checkLauncherUpdates
				)
				SettingsHairline()
				UpdateSettingsRow(
					title: "Arknights",
					status: installation.isGameUpdateAvailable
						? L10n.string(SettingsStrings.updateAvailable) : versionText,
					isEnabled: $settings.automaticallyChecksGameUpdates,
					isChecking: installation.isDownloading,
					accentColor: accentColor,
					check: checkGameUpdates
				)
			}

			SettingsPanel(
				title: L10n.string(SettingsStrings.announcements), systemImage: "megaphone"
			) {
				SettingsActionRow(
					title: L10n.string(SettingsStrings.announcements),
					detail: L10n.string(SettingsStrings.announcementsDetail)
				) {
					Toggle(
						L10n.string(SettingsStrings.announcements),
						isOn: $settings.announcementsEnabled
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(accentColor)
				}
			}
		}
	}

	private var launcherStatusText: String {
		if communication.isCheckingLauncherUpdates { return L10n.string(SettingsStrings.checking) }
		if communication.launcherUpdate != nil {
			return L10n.string(SettingsStrings.updateAvailable)
		}
		return "v\(appVersion)"
	}

	private var versionText: String {
		installation.installedVersion ?? installation.configuration?.gameLatestVersion ?? "—"
	}
}
