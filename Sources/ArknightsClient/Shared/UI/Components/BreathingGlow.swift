// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// A slow accent halo behind the current primary operation. The breathing cycle only runs
/// while decorative motion is visible; Reduce Motion and hidden windows keep a static halo.
private struct BreathingGlowModifier<S: Shape>: ViewModifier {
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
						BreathingGlowHalo(tint: tint, shape: shape)
							.transition(.opacity)
							.allowsHitTesting(false)
							.accessibilityHidden(true)
					}
				}
				.animation(LauncherMotion.fade(reduceMotion: reduceMotion), value: isActive)
			}
	}
}

private struct BreathingGlowHalo<S: Shape>: View {
	let tint: Color
	let shape: S
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.decorativeMotionEnabled) private var decorativeMotionEnabled
	@State private var motionClock = DecorativeMotionClock()

	private var cycle: TimeInterval { LauncherMotion.breathingCycle }

	var body: some View {
		Group {
			if decorativeMotionEnabled && !reduceMotion {
				TimelineView(.animation(minimumInterval: 1 / 24)) { context in
					let phase = motionClock.phase(at: context.date, cycleDuration: cycle)
					halo(intensity: intensity(at: phase))
				}
			} else {
				halo(intensity: reduceMotion ? 0.5 : intensity(at: motionClock.pausedPhase))
			}
		}
		.onAppear {
			if decorativeMotionEnabled {
				motionClock.begin(at: .now, cycleDuration: cycle)
			}
		}
		.onChange(of: decorativeMotionEnabled) { _, isEnabled in
			if isEnabled {
				motionClock.resume(at: .now, cycleDuration: cycle)
			} else {
				motionClock.pause(at: .now, cycleDuration: cycle)
			}
		}
	}

	private func halo(intensity: Double) -> some View {
		shape
			.fill(tint)
			.scaleEffect(0.94 + 0.08 * intensity)
			.blur(radius: 12 + 8 * intensity)
			.opacity(0.18 + 0.22 * intensity)
	}

	/// Eased sine so the halo lingers at both ends of a breath.
	private func intensity(at phase: Double) -> Double {
		(1 - cos(phase * 2 * .pi)) / 2
	}
}

extension View {
	/// Adds the shared breathing accent halo behind `shape` while `isActive` is true.
	func breathingGlow<S: Shape>(tint: Color, isActive: Bool, in shape: S) -> some View {
		modifier(BreathingGlowModifier(tint: tint, isActive: isActive, shape: shape))
	}
}
