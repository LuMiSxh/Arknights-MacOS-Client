// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsCustomization
import ArknightsGameInstallation
import ArknightsGameRuntime
import ArknightsPresence

extension LauncherViewModel {
	/// Wires the callback channels between the controllers. Kept out of `init` so the
	/// construction order stays readable.
	func wireCallbacks() {
		storage.onStorageOverviewChanged = { [weak self] in
			self?.storageOverview.refreshNow()
		}
		settings.onResetReminderChanged = { [weak self] in
			self?.reminders.preferencesDidChange()
		}
		installation.onInstalledRegionsChanged = { [weak self] in
			self?.reminders.installedRegionsDidChange()
		}
		settings.onLauncherUpdateCheckRequested = { [weak self] in
			self?.actions.checkLauncherUpdates()
		}
		settings.onGameUpdateCheckRequested = { [weak self] in
			self?.actions.checkGameUpdates()
		}
		settings.onAnnouncementCheckRequested = { [weak self] in
			self?.actions.checkAnnouncements()
		}
		settings.onDynamicThemeChanged = { [weak self] in
			self?.customization.updateThemeColor()
		}
		settings.onCanaryFeaturesChanged = { [weak self] _ in
			self?.refreshInstalledRegionsAfterCanaryChange()
		}
		settings.onDiscordPresenceChanged = { [weak self] in
			self?.discordPresence.activityDidChange()
		}
		_ = lifecycle.observeActivityChanges { [weak self] in
			self?.scheduleCanaryRefreshIfIdle()
		}
		_ = lifecycle.observeActivityChanges { [weak self] in
			self?.discordPresence.activityDidChange()
		}
		installation.onMetadataRefreshCancellationRequested = { [weak self] in
			self?.refreshController.cancelForInstallationStart()
		}
		installation.onLaunchRequested = { [weak self] in
			self?.gameSession.launch()
		}
		gameSession.customGameIconURL = { [weak self] in
			guard let self else { return nil }
			return customization.hasCustomGameIcon ? paths.customGameIcon : nil
		}
		discordPresence.activityDidChange()
	}
}
