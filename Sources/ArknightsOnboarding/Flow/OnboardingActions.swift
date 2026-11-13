// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameRuntime
import Foundation

package struct OnboardingActions {
	package let selectRegion: @MainActor @Sendable (GameRegion) -> Void
	let resetArtwork: @MainActor () -> Void
	let installOrUpdate: () -> Void
	let pauseDownload: () -> Void
	let chooseInstallDirectory: () -> Void
	let locateExistingInstallation: () -> Void
	let installRuntime: @MainActor (RuntimeLane) async -> Bool
	let pauseRuntime: () -> Void
	let selectRuntimeLane: @MainActor (RuntimeLane) -> Bool
	let openLauncherUpdate: () -> Void
	let retryIntelTranslation: () async -> IntelTranslationState
	let installRosetta: () async -> IntelTranslationState

	package init(
		selectRegion: @escaping @MainActor @Sendable (GameRegion) -> Void,
		resetArtwork: @escaping @MainActor () -> Void,
		installOrUpdate: @escaping () -> Void,
		pauseDownload: @escaping () -> Void,
		chooseInstallDirectory: @escaping () -> Void,
		locateExistingInstallation: @escaping () -> Void,
		installRuntime: @escaping @MainActor (RuntimeLane) async -> Bool,
		pauseRuntime: @escaping () -> Void,
		selectRuntimeLane: @escaping @MainActor (RuntimeLane) -> Bool,
		openLauncherUpdate: @escaping () -> Void,
		retryIntelTranslation: @escaping () async -> IntelTranslationState,
		installRosetta: @escaping () async -> IntelTranslationState
	) {
		self.selectRegion = selectRegion
		self.resetArtwork = resetArtwork
		self.installOrUpdate = installOrUpdate
		self.pauseDownload = pauseDownload
		self.chooseInstallDirectory = chooseInstallDirectory
		self.locateExistingInstallation = locateExistingInstallation
		self.installRuntime = installRuntime
		self.pauseRuntime = pauseRuntime
		self.selectRuntimeLane = selectRuntimeLane
		self.openLauncherUpdate = openLauncherUpdate
		self.retryIntelTranslation = retryIntelTranslation
		self.installRosetta = installRosetta
	}
}
