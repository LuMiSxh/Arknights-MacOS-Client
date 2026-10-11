// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Shared placeholder for a value whose final geometry is already known. Leave `width`/`height`
/// `nil` to fill a cell whose size the caller already constrains (e.g. a grid thumbnail).
package struct SkeletonValue: View {
	var width: CGFloat?
	var height: CGFloat?
	var cornerRadius: CGFloat = 4
	var pulses = false

	package init(
		width: CGFloat? = nil,
		height: CGFloat? = nil,
		cornerRadius: CGFloat = 4,
		pulses: Bool = false
	) {
		self.width = width
		self.height = height
		self.cornerRadius = cornerRadius
		self.pulses = pulses
	}

	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	private let pulseCycleDuration = 1.8

	package var body: some View {
		Group {
			// Reduce Motion keeps the static baseline; the pulse only runs when motion is allowed.
			if pulses && !reduceMotion {
				ContinuousMotion(cycle: pulseCycleDuration, framesPerSecond: 30) { phase in
					placeholder(opacity: pulseOpacity(at: phase))
				}
			} else {
				placeholder(opacity: SkeletonValue.baselineOpacity)
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
}

#Preview("Skeleton") {
	VStack(alignment: .leading, spacing: 12) {
		SkeletonValue(width: 64, height: 14)
		SkeletonValue(width: 96, height: 14, pulses: true)
	}
	.padding()
}
