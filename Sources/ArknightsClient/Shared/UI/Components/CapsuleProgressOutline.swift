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

	/// A full, active outline marks work without measurable progress.
	private var showsIndeterminatePulse: Bool {
		isGlintActive && clampedProgress >= 1 && !reduceMotion
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
					.opacity(showsIndeterminatePulse ? 0 : 1)
			}
			.overlay {
				if showsIndeterminatePulse {
					CapsuleIndeterminatePulse(tint: tint, lineWidth: lineWidth)
						.transition(.opacity)
				} else if isGlintActive && clampedProgress > 0 && !reduceMotion {
					progressHead
					CapsuleProgressSweep(progress: clampedProgress, lineWidth: lineWidth)
				}
			}
			.animation(
				LauncherMotion.fade(reduceMotion: reduceMotion),
				value: showsIndeterminatePulse
			)
			.accessibilityHidden(true)
	}

	/// A soft glow at the leading edge of the transferred fraction.
	private var progressHead: some View {
		let tail = max(0, clampedProgress - min(0.035, clampedProgress))
		return Capsule()
			.inset(by: lineWidth / 2)
			.trim(from: tail, to: clampedProgress)
			.stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 3, lineCap: .round))
			.blur(radius: 4)
			.blendMode(.plusLighter)
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
		let segment = Capsule()
			.inset(by: lineWidth / 2)
			.trim(from: max(0, head - length), to: head)
		return ZStack {
			segment
				.stroke(
					Color.white.opacity(values.opacity * 0.6),
					style: StrokeStyle(lineWidth: lineWidth * 3, lineCap: .round)
				)
				.blur(radius: 3)
			segment
				.stroke(
					Color.white.opacity(values.opacity),
					style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
				)
		}
	}

	private func sweepValues(for phase: Double) -> (head: Double, opacity: Double) {
		let fadeIn = LauncherVisuals.Motion.progressSweepFadeIn
		let travel = LauncherVisuals.Motion.progressSweepTravel
		let fadeOut = LauncherVisuals.Motion.progressSweepFadeOut
		let elapsed = phase * cycleDuration
		if elapsed < fadeIn {
			let fraction = smoothstep(elapsed / fadeIn)
			return (0, 0.4 * fraction)
		}
		if elapsed < fadeIn + travel {
			return ((elapsed - fadeIn) / travel, 0.4)
		}
		if elapsed < fadeIn + travel + fadeOut {
			let fraction = smoothstep((elapsed - fadeIn - travel) / fadeOut)
			return (1, 0.4 * (1 - fraction))
		}
		return (0, 0)
	}

	private func smoothstep(_ value: Double) -> Double {
		let clamped = min(max(value, 0), 1)
		return clamped * clamped * (3 - 2 * clamped)
	}
}

/// Indeterminate work: an accent glint circles the outline while the ring breathes on the
/// same cycle as the primary action halo. The orbit eases without ever stopping, so it
/// reads as ongoing work rather than a looping progress fill.
private struct CapsuleIndeterminatePulse: View {
	let tint: Color
	let lineWidth: CGFloat
	@Environment(\.decorativeMotionEnabled) private var decorativeMotionEnabled
	@State private var motionClock = DecorativeMotionClock()

	private var cycle: TimeInterval { LauncherMotion.breathingCycle }

	var body: some View {
		Group {
			if decorativeMotionEnabled {
				TimelineView(.animation(minimumInterval: 1 / 30)) { context in
					pulse(phase: motionClock.phase(at: context.date, cycleDuration: cycle))
				}
			} else {
				pulse(phase: motionClock.pausedPhase)
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

	private func pulse(phase: Double) -> some View {
		let breath = (1 - cos(phase * 2 * .pi)) / 2
		let laps = LauncherVisuals.Motion.indeterminateOrbitLaps
		let lap = (phase * laps).truncatingRemainder(dividingBy: 1)
		// Blend linear travel with an eased lap so the glint surges and settles but never halts.
		let head = 0.6 * lap + 0.4 * smoothstep(lap)
		let tail = LauncherVisuals.Motion.indeterminateGlintLength
		return ZStack {
			outline
				.stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
				.opacity(0.35 + 0.15 * breath)
			glint(head: head, length: tail, width: lineWidth * 2)
				.blur(radius: 6)
				.opacity(0.3 + 0.1 * breath)
			glint(head: head, length: tail * 0.5, width: lineWidth)
				.blur(radius: 1)
				.opacity(0.65)
		}
	}

	private var outline: some Shape {
		Capsule().inset(by: lineWidth / 2)
	}

	/// Draws a segment ending at `head`, split in two where it wraps past the path start.
	private func glint(head: Double, length: Double, width: CGFloat) -> some View {
		let start = head - length
		let style = StrokeStyle(lineWidth: width, lineCap: .round)
		return ZStack {
			outline.trim(from: max(0, start), to: head).stroke(tint, style: style)
			if start < 0 {
				outline.trim(from: 1 + start, to: 1).stroke(tint, style: style)
			}
		}
	}

	private func smoothstep(_ value: Double) -> Double {
		let clamped = min(max(value, 0), 1)
		return clamped * clamped * (3 - 2 * clamped)
	}
}
