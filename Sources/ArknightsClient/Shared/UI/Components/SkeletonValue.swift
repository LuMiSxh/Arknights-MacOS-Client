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
	@State private var isPulsing = false

	var body: some View {
		RoundedRectangle(cornerRadius: cornerRadius)
			.fill(Color.primary.opacity(fillOpacity))
			.frame(width: width, height: height)
			.frame(
				maxWidth: width == nil ? .infinity : nil, maxHeight: height == nil ? .infinity : nil
			)
			.accessibilityHidden(true)
			.task(id: pulses && !reduceMotion) {
				guard pulses, !reduceMotion else {
					isPulsing = false
					return
				}
				withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
					isPulsing = true
				}
			}
	}

	private var fillOpacity: Double {
		guard pulses, !reduceMotion else { return SkeletonValue.baselineOpacity }
		return isPulsing ? SkeletonValue.pulseHighOpacity : SkeletonValue.baselineOpacity
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
