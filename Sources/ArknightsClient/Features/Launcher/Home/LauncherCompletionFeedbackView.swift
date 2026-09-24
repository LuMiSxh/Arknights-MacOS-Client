// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Briefly draws the verified-installation checkmark without delaying the next action.
struct LauncherCompletionFeedbackView: View {
	let feedbackID: UUID
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var isVisible = false

	var body: some View {
		Group {
			if #available(macOS 26, *) {
				Image(systemName: "checkmark.circle.fill")
					.symbolEffect(.drawOn, isActive: isVisible)
			} else {
				Image(systemName: "checkmark.circle.fill")
					.opacity(isVisible ? 1 : 0)
			}
		}
		.font(.system(size: 15, weight: .semibold))
		.foregroundStyle(LauncherVisuals.success)
		.accessibilityHidden(true)
		.task(id: feedbackID) {
			guard !Task.isCancelled else { return }
			if reduceMotion {
				isVisible = true
				return
			}
			if #available(macOS 26, *) {
				isVisible = true
			} else {
				withAnimation(.easeIn(duration: LauncherVisuals.Motion.primaryAction)) {
					isVisible = true
				}
			}
		}
	}
}
