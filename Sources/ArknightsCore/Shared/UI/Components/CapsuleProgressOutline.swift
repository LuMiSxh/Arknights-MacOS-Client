// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct CapsuleProgressOutline: View {
	let progress: Double
	// Kept for existing call sites; the theme supplies the color.
	let tint: Color
	var isGlintActive = false
	var lineWidth: CGFloat = 2
	var track: Color = .clear
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.launcherTheme) private var theme

	private var clampedProgress: Double {
		min(max(progress, 0), 1)
	}

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
						theme.accentFill,
						style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
					)
					.opacity(showsIndeterminatePulse ? 0 : 1)
			}
			.overlay {
				if showsIndeterminatePulse {
					CapsuleIndeterminatePulse(tint: theme.accentFill, lineWidth: lineWidth)
						.transition(.opacity)
				} else if isGlintActive && clampedProgress > 0 && !reduceMotion {
					CapsuleProgressSweep(
						progress: clampedProgress, lineWidth: lineWidth, glint: theme.textPrimary)
				}
			}
			.animation(
				LauncherMotion.fade(reduceMotion: reduceMotion),
				value: showsIndeterminatePulse
			)
			.accessibilityHidden(true)
	}
}

private struct CapsuleProgressSweep: View {
	let progress: Double
	let lineWidth: CGFloat
	let glint: Color

	private var cycleDuration: TimeInterval {
		LauncherMotion.Cycle.progressSweepFadeIn
			+ LauncherMotion.Cycle.progressSweepTravel
			+ LauncherMotion.Cycle.progressSweepFadeOut
			+ LauncherMotion.Cycle.progressSweepPause
	}

	var body: some View {
		ContinuousMotion(cycle: cycleDuration, framesPerSecond: 30) { phase in
			sweep(phase: phase)
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
				glint.opacity(values.opacity),
				style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
			)
	}

	private func sweepValues(for phase: Double) -> (head: Double, opacity: Double) {
		let fadeIn = LauncherMotion.Cycle.progressSweepFadeIn
		let travel = LauncherMotion.Cycle.progressSweepTravel
		let fadeOut = LauncherMotion.Cycle.progressSweepFadeOut
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

// Indeterminate work: an accent glint circles the outline while the ring pulses on the
// same cycle as the primary action halo. The orbit eases without ever stopping, so it
// reads as ongoing work rather than a looping progress fill.
private struct CapsuleIndeterminatePulse: View {
	let tint: Color
	let lineWidth: CGFloat

	private var cycle: TimeInterval { LauncherMotion.Cycle.pulse }

	var body: some View {
		ContinuousMotion(cycle: cycle, framesPerSecond: 30) { phase in
			pulse(phase: phase)
		}
	}

	private func pulse(phase: Double) -> some View {
		let breath = (1 - cos(phase * 2 * .pi)) / 2
		let laps = LauncherMotion.Cycle.indeterminateOrbitLaps
		let lap = (phase * laps).truncatingRemainder(dividingBy: 1)
		// Blend linear travel with an eased lap so the glint surges and settles but never halts.
		let head = 0.6 * lap + 0.4 * smoothstep(lap)
		let tail = LauncherMotion.Cycle.indeterminateGlintLength
		return ZStack {
			outline
				.stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
				.opacity(0.35 + 0.15 * breath)
			glint(head: head, length: tail * 0.5, width: lineWidth)
				.blur(radius: 1)
				.opacity(0.65)
		}
	}

	private var outline: some Shape {
		Capsule().inset(by: lineWidth / 2)
	}

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
