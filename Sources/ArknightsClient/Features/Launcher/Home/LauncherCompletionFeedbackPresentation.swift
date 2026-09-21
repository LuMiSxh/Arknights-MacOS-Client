// SPDX-License-Identifier: MPL-2.0

import Foundation

enum LauncherCompletionFeedbackPresentation {
	static func isVisible(
		_ feedback: InstallationCompletionFeedback?,
		currentRegion: GameRegion,
		activity: LauncherActivity,
		hasFailure: Bool
	) -> Bool {
		guard let feedback else { return false }
		return feedback.region == currentRegion && activity == .idle && !hasFailure
	}
}
