// SPDX-License-Identifier: MPL-2.0

import Foundation

// What the Install step still has to download. A setup rerun on a complete install needs
// nothing, so its footer says Continue and no download starts.
nonisolated struct OnboardingInstallPlan: Equatable {
	let gameNeedsDownload: Bool
	let runtimeNeedsDownload: Bool

	init(gameIsInstalled: Bool, gameIsDownloading: Bool, runtimeIsInstalled: Bool) {
		gameNeedsDownload = !gameIsInstalled && !gameIsDownloading
		runtimeNeedsDownload = !runtimeIsInstalled
	}

	var needsDownload: Bool { gameNeedsDownload || runtimeNeedsDownload }

	var primaryTitle: String { needsDownload ? "Download and Continue" : "Continue" }
}
