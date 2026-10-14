// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// A soft highlight that follows the pointer across an action surface. It is purely
/// decorative: it never intercepts hits and disappears for disabled controls. Reduce Motion
/// pins the highlight to the center instead of tracking the pointer.
private struct PointerSheenModifier<S: Shape>: ViewModifier {
	let shape: S
	let tint: Color
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
	@Environment(\.isEnabled) private var isEnabled
	@State private var location: CGPoint?

	func body(content: Content) -> some View {
		content
			.overlay {
				GeometryReader { proxy in
					if let location, isEnabled, !reduceTransparency {
						shape
							.fill(sheenGradient(at: location, in: proxy.size))
							.blendMode(.plusLighter)
							.transition(.opacity)
					}
				}
				.allowsHitTesting(false)
				.animation(
					LauncherMotion.animation(.hover, reduceMotion: reduceMotion),
					value: location == nil
				)
			}
			.onContinuousHover { phase in
				switch phase {
				case .active(let point):
					location = reduceMotion ? .zero : point
				case .ended:
					location = nil
				}
			}
	}

	private func sheenGradient(at location: CGPoint, in size: CGSize) -> RadialGradient {
		let width = max(size.width, 1)
		let height = max(size.height, 1)
		let center =
			reduceMotion
			? UnitPoint.center
			: UnitPoint(x: location.x / width, y: location.y / height)
		return RadialGradient(
			colors: [tint.opacity(0.30), tint.opacity(0.08), tint.opacity(0)],
			center: center,
			startRadius: 0,
			endRadius: max(width, height) * 0.55
		)
	}
}

extension View {
	/// Adds the shared pointer-following highlight inside `shape`.
	func pointerSheen<S: Shape>(tint: Color, in shape: S) -> some View {
		modifier(PointerSheenModifier(shape: shape, tint: tint))
	}
}
