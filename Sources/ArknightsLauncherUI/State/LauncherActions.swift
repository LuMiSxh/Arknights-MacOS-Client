// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameRuntime
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

	/// Installs the pinned runtime for `lane` and selects it after a successful install.
	@discardableResult
	func installRuntime(_ lane: RuntimeLane) async -> Bool
	/// Switches to an already installed lane. The change applies at the next launch.
	@discardableResult
	func selectRuntimeLane(_ lane: RuntimeLane) -> Bool
	/// Removes the runtime of the lane that is not selected.
	@discardableResult
	func removeOtherRuntime() -> Bool

	/// True while a diagnostics archive is being written; views disable their Save buttons.
	var isSavingDiagnostics: Bool { get }

	/// Writes redacted logs and settings to a zip the user reviews and attaches to a report.
	func saveDiagnostics() async
}

extension LauncherActions {
	@discardableResult
	package func refreshIntelTranslationForUI() async -> IntelTranslationState {
		await refreshIntelTranslationForUI(force: false)
	}
}
