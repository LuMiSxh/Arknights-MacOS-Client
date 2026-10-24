// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

/// Every action the launcher UI can trigger. Views call these rather than the controllers,
/// because each one carries policy: the ACE warning and the guards that keep checks from
/// firing during a storage migration. `LauncherViewModel` drives the real controllers.
/// In debug builds, `SimulatedLauncherActions` replaces it while a developer simulation runs.
@MainActor
package protocol LauncherActions {
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

	/// Writes logs and settings to a zip the user reviews and attaches to a report.
	func saveDiagnostics() async
}

extension LauncherActions {
	@discardableResult
	package func refreshIntelTranslationForUI() async -> IntelTranslationState {
		await refreshIntelTranslationForUI(force: false)
	}
}
