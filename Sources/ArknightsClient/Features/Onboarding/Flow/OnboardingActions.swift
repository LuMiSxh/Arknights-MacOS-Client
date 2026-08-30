// SPDX-License-Identifier: MPL-2.0

import Foundation

struct OnboardingActions {
	let selectRegion: @MainActor @Sendable (GameRegion) -> Void
	let resetArtwork: () -> Void
	let installOrUpdate: () -> Void
	let openLauncherUpdate: () -> Void
	let retryIntelTranslation: () async -> IntelTranslationState
	let installRosetta: () async -> IntelTranslationState
}
