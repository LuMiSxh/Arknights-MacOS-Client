// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct UpdatesSettingsPage: View {
	@Bindable var model: LauncherViewModel

	var body: some View {
		SettingsPage(
			title: "Updates", subtitle: "Keep the launcher and game current",
			accentColor: model.accentColor
		) {
			SettingsPanel(title: "Automatic Checks", systemImage: "arrow.trianglehead.2.clockwise")
			{
				UpdateSettingsRow(
					title: "Launcher",
					status: model.launcherUpdateStatus ?? "Not checked",
					isEnabled: $model.automaticallyChecksLauncherUpdates,
					isChecking: model.isCheckingLauncherUpdates,
					accentColor: model.accentColor,
					check: model.checkLauncherUpdates
				)
				SettingsHairline()
				UpdateSettingsRow(
					title: "Arknights",
					status: model.isGameUpdateAvailable ? "Update available" : model.versionText,
					isEnabled: $model.automaticallyChecksGameUpdates,
					isChecking: model.isDownloading,
					accentColor: model.accentColor,
					check: model.checkGameUpdates
				)
			}

			SettingsPanel(title: "Announcements", systemImage: "megaphone") {
				SettingsActionRow(
					title: "Announcements",
					detail: "Show occasional project messages once per announcement."
				) {
					Toggle("Announcements", isOn: $model.announcementsEnabled)
						.labelsHidden()
						.toggleStyle(.switch)
						.tint(model.accentColor)
				}
			}
		}
	}
}
