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
					title: "Launcher updates",
					explanation:
						"Checks for new launcher versions automatically. Turning it on checks now.",
					status: launcherStatusText,
					isEnabled: $settings.automaticallyChecksLauncherUpdates,
					isChecking: communication.isCheckingLauncherUpdates,
					isDisabled: !communication.canOpenLauncherUpdate,
					check: checkLauncherUpdates
				)
				SettingsHairline()
				UpdateSettingsRow(
					title: "Game updates",
					explanation:
						"Checks for new game versions automatically. Turning it on checks now.",
					status: gameStatusText,
					isEnabled: $settings.automaticallyChecksGameUpdates,
					isChecking: lifecycle.state.refresh.isChecking,
					isDisabled: lifecycle.state.refresh.isChecking
						|| !lifecycle.canBeginExclusiveActivity,
					check: actions.checkGameUpdates
				)
				if let activityLockReason {
					SettingsFootnote(activityLockReason)
				}
			}

			SettingsPanel(
				title: "Project news"
			) {
				SettingsActionRow(
					title: Self.announcementsTitle,
					detail: announcementsDetail
				) {
					SettingsToggle(
						Self.announcementsTitle,
						isOn: $settings.announcementsEnabled,
					)
					.disabled(isAnnouncementsLocked)
				}
			}
		}
	}

	private var isAnnouncementsLocked: Bool {
		lifecycle.activity == .maintaining(.migratingStorage)
	}

	private var announcementsDetail: String? {
		isAnnouncementsLocked
			? lifecycle.activity.lockReason
			: "Shows each project message once in the launcher."
	}

	private var activityLockReason: String? {
		lifecycle.canBeginExclusiveActivity ? nil : lifecycle.activity.lockReason
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
