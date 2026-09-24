// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Shared placeholder for a value whose final geometry is already known. Leave `width`/`height`
/// `nil` to fill a cell whose size the caller already constrains (e.g. a grid thumbnail).
struct SkeletonValue: View {
	var width: CGFloat?
	var height: CGFloat?
	var cornerRadius: CGFloat = 4
	var pulses = false

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.decorativeMotionEnabled) private var decorativeMotionEnabled
	@State private var motionClock = DecorativeMotionClock()

	private let pulseCycleDuration = 1.8

	var body: some View {
		Group {
			if pulses && !reduceMotion {
				if decorativeMotionEnabled {
					TimelineView(.animation(minimumInterval: 1 / 30)) { context in
						placeholder(
							opacity: pulseOpacity(
								at: motionClock.phase(
									at: context.date,
									cycleDuration: pulseCycleDuration
								)))
					}
				} else {
					placeholder(opacity: pulseOpacity(at: motionClock.pausedPhase))
				}
			} else {
				placeholder(opacity: SkeletonValue.baselineOpacity)
			}
		}
		.onAppear {
			if decorativeMotionEnabled {
				motionClock.begin(at: .now, cycleDuration: pulseCycleDuration)
			}
		}
		.onChange(of: decorativeMotionEnabled) { _, isEnabled in
			if isEnabled {
				motionClock.resume(at: .now, cycleDuration: pulseCycleDuration)
			} else {
				motionClock.pause(at: .now, cycleDuration: pulseCycleDuration)
			}
		}
	}

	private func placeholder(opacity: Double) -> some View {
		RoundedRectangle(cornerRadius: cornerRadius)
			.fill(Color.primary.opacity(opacity))
			.frame(width: width, height: height)
			.frame(
				maxWidth: width == nil ? .infinity : nil, maxHeight: height == nil ? .infinity : nil
			)
			.accessibilityHidden(true)
	}

	private func pulseOpacity(at phase: Double) -> Double {
		let wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2
		let easedWave = wave * wave * (3 - 2 * wave)
		return SkeletonValue.baselineOpacity
			+ (SkeletonValue.pulseHighOpacity - SkeletonValue.baselineOpacity) * easedWave
	}

	static let baselineOpacity = 0.12
	static let pulseHighOpacity = 0.22
	/// Minimum time shown, so a near-instant measurement doesn't read as a flicker.
	static let minimumDuration: Duration = .milliseconds(120)
}

#Preview("Skeleton") {
	VStack(alignment: .leading, spacing: 12) {
		SkeletonValue(width: 64, height: 14)
		SkeletonValue(width: 96, height: 14, pulses: true)
	}
	.padding()
}
