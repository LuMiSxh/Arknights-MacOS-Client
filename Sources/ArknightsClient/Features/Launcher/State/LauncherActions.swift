// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Every action the launcher UI can trigger. Views call these rather than the controllers,
/// because each one carries policy: the ACE warning and the guards that keep checks from
/// firing during a storage migration. `LiveLauncherActions` drives the real controllers.
/// In debug builds, `SimulatedLauncherActions` replaces it while a developer simulation runs.
@MainActor
protocol LauncherActions {
	var canRequestDockLaunch: Bool { get }

	func selectRegion(_ newRegion: GameRegion)

	func installOrUpdate()
	func repairGame()
	func cancelDownload()

	func checkGameUpdates()
	func checkLauncherUpdates()
	func checkAnnouncements()
	func launcherUpdateCheckForOnboarding() async -> LauncherUpdateCheckOutcome
	func openLauncherUpdate()
	@discardableResult
	func refreshIntelTranslationForUI(force: Bool) async -> IntelTranslationState

	func launch()
	func confirmACEWarningAndLaunch()
	func cancelACEWarning()
	func stopGame()
	func stopGameForApplicationTermination()
	func launchFromDock(region: GameRegion) async -> Bool

	func chooseInstallDirectory()
	func locateExistingInstallation()
	func resetAllLauncherSettings()
	func uninstallGame()
	func resetArtwork()

	@discardableResult
	func installRosetta() async -> IntelTranslationState
}

extension LauncherActions {
	@discardableResult
	func refreshIntelTranslationForUI() async -> IntelTranslationState {
		await refreshIntelTranslationForUI(force: false)
	}
}
