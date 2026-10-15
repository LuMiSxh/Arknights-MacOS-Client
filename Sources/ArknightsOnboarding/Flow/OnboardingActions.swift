// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

package struct OnboardingActions {
	package let selectRegion: @MainActor @Sendable (GameRegion) -> Void
	let resetArtwork: @MainActor () -> Void
	let installOrUpdate: () -> Void
	let openLauncherUpdate: () -> Void
	let retryIntelTranslation: () async -> IntelTranslationState
	let installRosetta: () async -> IntelTranslationState

	package init(
		selectRegion: @escaping @MainActor @Sendable (GameRegion) -> Void,
		resetArtwork: @escaping @MainActor () -> Void,
		installOrUpdate: @escaping () -> Void,
		openLauncherUpdate: @escaping () -> Void,
		retryIntelTranslation: @escaping () async -> IntelTranslationState,
		installRosetta: @escaping () async -> IntelTranslationState
	) {
		self.selectRegion = selectRegion
		self.resetArtwork = resetArtwork
		self.installOrUpdate = installOrUpdate
		self.openLauncherUpdate = openLauncherUpdate
		self.retryIntelTranslation = retryIntelTranslation
		self.installRosetta = installRosetta
	}
}
