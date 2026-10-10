// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

/// Briefly draws the verified-installation checkmark without delaying the next action.
struct LauncherCompletionFeedbackView: View {
	let feedbackID: UUID
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var isVisible = false
	@State private var isRippling = false

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
		.font(LauncherVisuals.Typography.completionLabel)
		.foregroundStyle(LauncherVisuals.success)
		.background {
			if !reduceMotion {
				Circle()
					.stroke(LauncherVisuals.success, lineWidth: 1.5)
					.scaleEffect(isRippling ? 2.6 : 0.6)
					.opacity(isRippling ? 0 : 0.75)
			}
		}
		.accessibilityHidden(true)
		.task(id: feedbackID) {
			guard !Task.isCancelled else { return }
			if reduceMotion {
				isVisible = true
				return
			}
			isRippling = false
			withAnimation(LauncherMotion.animation(.ripple, reduceMotion: reduceMotion)) {
				isRippling = true
			}
			if #available(macOS 26, *) {
				isVisible = true
			} else {
				withAnimation(LauncherMotion.animation(.settle, reduceMotion: reduceMotion)) {
					isVisible = true
				}
			}
		}
	}
}
