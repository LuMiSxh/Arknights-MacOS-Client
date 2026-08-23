// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct UpdatesSettingsPage: View {
	@Bindable var model: LauncherViewModel

	var body: some View {
		SettingsPage(
			title: L10n.string(SettingsStrings.updatesTitle),
			subtitle: L10n.string(SettingsStrings.updatesSubtitle),
			accentColor: model.accentColor
		) {
			SettingsPanel(
				title: L10n.string(SettingsStrings.automaticChecks),
				systemImage: "arrow.trianglehead.2.clockwise"
			) {
				UpdateSettingsRow(
					title: "Launcher",
					status: launcherStatusText,
					isEnabled: $model.automaticallyChecksLauncherUpdates,
					isChecking: model.isCheckingLauncherUpdates,
					accentColor: model.accentColor,
					check: model.checkLauncherUpdates
				)
				SettingsHairline()
				UpdateSettingsRow(
					title: "Arknights",
					status: model.isGameUpdateAvailable
						? L10n.string(SettingsStrings.updateAvailable) : model.versionText,
					isEnabled: $model.automaticallyChecksGameUpdates,
					isChecking: model.isDownloading,
					accentColor: model.accentColor,
					check: model.checkGameUpdates
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
						isOn: $model.announcementsEnabled
					)
					.labelsHidden()
					.toggleStyle(.switch)
					.tint(model.accentColor)
				}
			}
		}
	}

	private var launcherStatusText: String {
		if model.isCheckingLauncherUpdates { return L10n.string(SettingsStrings.checking) }
		if model.launcherUpdate != nil { return L10n.string(SettingsStrings.updateAvailable) }
		return "v\(model.appVersion)"
	}
}
