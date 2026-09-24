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
	@Environment(\.decorativeMotionEnabled) private var decorativeMotionEnabled
	@State private var motionClock = DecorativeMotionClock()

	private var cycleDuration: TimeInterval {
		LauncherVisuals.Motion.progressSweepFadeIn
			+ LauncherVisuals.Motion.progressSweepTravel
			+ LauncherVisuals.Motion.progressSweepFadeOut
			+ LauncherVisuals.Motion.progressSweepPause
	}

	var body: some View {
		Group {
			if decorativeMotionEnabled {
				TimelineView(.animation(minimumInterval: 1 / 30)) { context in
					sweep(phase: motionClock.phase(at: context.date, cycleDuration: cycleDuration))
				}
			} else {
				sweep(phase: motionClock.pausedPhase)
			}
		}
		.onAppear {
			if decorativeMotionEnabled {
				motionClock.begin(at: .now, cycleDuration: cycleDuration)
			}
		}
		.onChange(of: decorativeMotionEnabled) { _, isEnabled in
			if isEnabled {
				motionClock.resume(at: .now, cycleDuration: cycleDuration)
			} else {
				motionClock.pause(at: .now, cycleDuration: cycleDuration)
			}
		}
	}

	private func sweep(phase: Double) -> some View {
		let values = sweepValues(for: phase)
		let head = values.head * progress
		let length = min(0.06, progress * 0.25)
		return Capsule()
			.inset(by: lineWidth / 2)
			.trim(from: max(0, head - length), to: head)
			.stroke(
				Color.white.opacity(values.opacity),
				style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
			)
	}

	private func sweepValues(for phase: Double) -> (head: Double, opacity: Double) {
		let fadeIn = LauncherVisuals.Motion.progressSweepFadeIn
		let travel = LauncherVisuals.Motion.progressSweepTravel
		let fadeOut = LauncherVisuals.Motion.progressSweepFadeOut
		let elapsed = phase * cycleDuration
		if elapsed < fadeIn {
			let fraction = smoothstep(elapsed / fadeIn)
			return (0, 0.22 * fraction)
		}
		if elapsed < fadeIn + travel {
			return ((elapsed - fadeIn) / travel, 0.22)
		}
		if elapsed < fadeIn + travel + fadeOut {
			let fraction = smoothstep((elapsed - fadeIn - travel) / fadeOut)
			return (1, 0.22 * (1 - fraction))
		}
		return (0, 0)
	}

	private func smoothstep(_ value: Double) -> Double {
		let clamped = min(max(value, 0), 1)
		return clamped * clamped * (3 - 2 * clamped)
	}
}
