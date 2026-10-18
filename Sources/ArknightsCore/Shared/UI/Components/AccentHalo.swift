// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// A still accent halo behind the current primary operation. It plays one pulse when it
/// appears, unless Reduce Motion or the decorative motion gate forbids it.
private struct AccentHaloModifier<S: Shape>: ViewModifier {
	let tint: Color
	let isActive: Bool
	let shape: S
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency

	func body(content: Content) -> some View {
		content
			.background {
				ZStack {
					if isActive && !reduceTransparency {
						AccentHalo(tint: tint, shape: shape)
							.transition(.opacity)
							.allowsHitTesting(false)
							.accessibilityHidden(true)
					}
				}
				.animation(LauncherMotion.fade(reduceMotion: reduceMotion), value: isActive)
			}
	}
}

private struct AccentHalo<S: Shape>: View {
	static var restingIntensity: Double { 0.5 }

	let tint: Color
	let shape: S
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.decorativeMotionEnabled) private var decorativeMotionEnabled
	@State private var pulseCount = 0

	private var cycle: TimeInterval { LauncherMotion.Cycle.breathing }

	var body: some View {
		shape
			.fill(tint)
			.keyframeAnimator(initialValue: Self.restingIntensity, trigger: pulseCount) {
				content, intensity in
				content
					.scaleEffect(0.94 + 0.08 * intensity)
					.blur(radius: 12 + 8 * intensity)
					.opacity(0.18 + 0.22 * intensity)
			} keyframes: { _ in
				CubicKeyframe(1, duration: cycle / 2)
				CubicKeyframe(Self.restingIntensity, duration: cycle / 2)
			}
			.onAppear {
				if decorativeMotionEnabled && !reduceMotion {
					pulseCount += 1
				}
			}
	}
}

extension View {
	package func accentHalo<S: Shape>(tint: Color, isActive: Bool, in shape: S) -> some View {
		modifier(AccentHaloModifier(tint: tint, isActive: isActive, shape: shape))
	}
}
