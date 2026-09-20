// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Draws transfer progress around a capsule without changing the capsule's layout.
struct CapsuleProgressOutline: View {
	let progress: Double
	let tint: Color
	var isGlintActive = false
	var lineWidth: CGFloat = 2
	var track: Color = LauncherVisuals.hairline
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	private var clampedProgress: Double {
		min(max(progress, 0), 1)
	}

	var body: some View {
		Capsule()
			.inset(by: lineWidth / 2)
			.stroke(track, lineWidth: lineWidth)
			.overlay {
				Capsule()
					.inset(by: lineWidth / 2)
					.trim(from: 0, to: clampedProgress)
					.stroke(
						tint,
						style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
					)
			}
			.overlay {
				if isGlintActive && clampedProgress > 0 && !reduceMotion {
					CapsuleProgressSweep(progress: clampedProgress, lineWidth: lineWidth)
				}
			}
			.accessibilityHidden(true)
	}
}

private struct CapsuleProgressSweep: View {
	let progress: Double
	let lineWidth: CGFloat

	private struct SweepValues {
		var head = 0.0
		var opacity = 0.0
	}

	var body: some View {
		Color.clear
			.keyframeAnimator(initialValue: SweepValues(), repeating: true) { _, values in
				let head = values.head * progress
				let length = min(0.06, progress * 0.25)
				Capsule()
					.inset(by: lineWidth / 2)
					.trim(from: max(0, head - length), to: head)
					.stroke(
						Color.white.opacity(values.opacity),
						style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
					)
			} keyframes: { _ in
				KeyframeTrack(\.head) {
					LinearKeyframe(0, duration: LauncherVisuals.Motion.progressSweepFadeIn)
					LinearKeyframe(1, duration: LauncherVisuals.Motion.progressSweepTravel)
					LinearKeyframe(1, duration: LauncherVisuals.Motion.progressSweepFadeOut)
					LinearKeyframe(0, duration: LauncherVisuals.Motion.progressSweepPause)
				}
				KeyframeTrack(\.opacity) {
					CubicKeyframe(0.22, duration: LauncherVisuals.Motion.progressSweepFadeIn)
					LinearKeyframe(0.22, duration: LauncherVisuals.Motion.progressSweepTravel)
					CubicKeyframe(0, duration: LauncherVisuals.Motion.progressSweepFadeOut)
					LinearKeyframe(0, duration: LauncherVisuals.Motion.progressSweepPause)
				}
			}
	}
}
