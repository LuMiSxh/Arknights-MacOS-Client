// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsCustomization
import ArknightsGameInstallation
import ArknightsGameRuntime

/// Every controller and action the settings sheet reads. The composition root builds it once.
struct LauncherSettingsDependencies {
	let settings: LauncherPreferencesController
	let customization: CustomizationController
	let communication: LauncherCommunicationController
	let installation: InstallationController
	let gameSession: GameSessionController
	let runtimeSelection: RuntimeSelectionController
	let intelTranslation: IntelTranslationController
	let lifecycle: LauncherLifecycleStore
	let reminders: ResetReminderController
	let screenshots: GameScreenshotController
	let storage: StorageMaintenanceController
	let storageOverview: StorageOverviewController
	let playtimeStatistics: PlaytimeStatisticsController
	let presetCatalog: PresetCatalogService
	let launcherIconManager: LauncherIconManager
	let branding: LauncherBranding?
	let actions: any LauncherActions
}

extension LauncherViewModel {
	var settingsDependencies: LauncherSettingsDependencies {
		LauncherSettingsDependencies(
			settings: settings,
			customization: customization,
			communication: communication,
			installation: installation,
			gameSession: gameSession,
			runtimeSelection: runtimeSelection,
			intelTranslation: intelTranslation,
			lifecycle: lifecycle,
			reminders: reminders,
			screenshots: screenshots,
			storage: storage,
			storageOverview: storageOverview,
			playtimeStatistics: playtimeStatistics,
			presetCatalog: presetCatalog,
			launcherIconManager: launcherIconManager,
			branding: refreshController.branding,
			actions: actions
		)
	}
}
