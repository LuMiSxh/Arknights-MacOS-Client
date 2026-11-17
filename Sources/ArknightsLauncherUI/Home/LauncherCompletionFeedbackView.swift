// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct LauncherCompletionFeedbackView: View {
	let feedbackID: UUID
	@Environment(\.launcherTheme) private var theme
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var isVisible = false
	@State private var isRippling = false
	private static let rippleLineWidth: CGFloat = 1.5
	private static let rippleStartScale: CGFloat = 0.6
	private static let rippleEndScale: CGFloat = 2.6
	private static let rippleOpacity: Double = 0.75

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
		.font(LauncherTokens.Typography.completionLabel)
		.foregroundStyle(theme.successInk)
		.background {
			if !reduceMotion {
				Circle()
					.stroke(theme.successInk, lineWidth: Self.rippleLineWidth)
					.scaleEffect(isRippling ? Self.rippleEndScale : Self.rippleStartScale)
					.opacity(isRippling ? 0 : Self.rippleOpacity)
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
