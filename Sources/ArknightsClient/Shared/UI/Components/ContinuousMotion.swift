// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Drives a looping decorative animation and hands `content` a phase in `0..<1`.
///
/// The phase advances only while decorative motion is visible and Reduce Motion is off.
/// Otherwise the content receives a frozen phase, so hidden windows resume where they stopped.
struct ContinuousMotion<Content: View>: View {
	let cycle: TimeInterval
	let framesPerSecond: Double
	let reducedMotionPhase: Double?
	let content: (Double) -> Content

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.decorativeMotionEnabled) private var decorativeMotionEnabled
	@State private var motionClock = DecorativeMotionClock()

	/// - Parameters:
	///   - cycle: Seconds for one full loop.
	///   - framesPerSecond: Upper bound for timeline updates.
	///   - reducedMotionPhase: Fixed phase shown under Reduce Motion. `nil` keeps the paused phase.
	init(
		cycle: TimeInterval,
		framesPerSecond: Double,
		reducedMotionPhase: Double? = nil,
		@ViewBuilder content: @escaping (Double) -> Content
	) {
		self.cycle = cycle
		self.framesPerSecond = framesPerSecond
		self.reducedMotionPhase = reducedMotionPhase
		self.content = content
	}

	var body: some View {
		Group {
			if Self.isAnimating(
				decorativeMotionEnabled: decorativeMotionEnabled, reduceMotion: reduceMotion)
			{
				TimelineView(.animation(minimumInterval: 1 / framesPerSecond)) { context in
					content(motionClock.phase(at: context.date, cycleDuration: cycle))
				}
			} else {
				content(
					Self.pausedPhase(
						reduceMotion: reduceMotion,
						reducedMotionPhase: reducedMotionPhase,
						clockPhase: motionClock.pausedPhase
					))
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

	static func isAnimating(decorativeMotionEnabled: Bool, reduceMotion: Bool) -> Bool {
		decorativeMotionEnabled && !reduceMotion
	}

	static func pausedPhase(
		reduceMotion: Bool,
		reducedMotionPhase: Double?,
		clockPhase: Double
	) -> Double {
		reduceMotion ? (reducedMotionPhase ?? clockPhase) : clockPhase
	}
}
