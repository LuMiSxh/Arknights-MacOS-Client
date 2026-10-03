// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Shared launcher motion curves. Views pick a semantic curve instead of a raw duration so
/// press, morph, reveal, and presentation timing stays consistent across features. Every
/// curve resolves to `nil` under Reduce Motion; callers that still need a state change to
/// read as a change use `fade(reduceMotion:)`.
enum LauncherMotion {
	enum Curve {
		/// Immediate, critically damped response while a control is held down.
		case press
		/// Springy settle after a press ends.
		case release
		/// Hover lift and pointer highlights.
		case hover
		/// Structural layout changes such as appearing controls or status swaps.
		case state
		/// Primary action shape and label morphing between operations.
		case morph
		/// HUD pill expansion into a detail panel.
		case expansion
		/// Content revealed inside an already visible surface.
		case reveal
		/// Popups and overlays entering the window.
		case present
		/// Popups and overlays leaving the window; faster than presentation.
		case dismiss
		/// Artwork, wordmark, and theme crossfades.
		case crossfade

		var animation: Animation {
			switch self {
			case .press: .spring(duration: 0.20, bounce: 0)
			case .release: .spring(duration: 0.46, bounce: 0.42)
			case .hover: .spring(duration: 0.32, bounce: 0.22)
			case .state: .spring(duration: 0.38, bounce: 0.16)
			case .morph: .spring(duration: 0.52, bounce: 0.30)
			case .expansion: .spring(duration: 0.46, bounce: 0.26)
			case .reveal: .spring(duration: 0.40, bounce: 0.12)
			case .present: .spring(duration: 0.50, bounce: 0.24)
			case .dismiss: .spring(duration: 0.24, bounce: 0)
			case .crossfade: .easeInOut(duration: 0.48)
			}
		}
	}

	/// Delay between siblings that enter together, such as HUD pills.
	static let staggerStep = 0.045
	static let pressedScale: CGFloat = 0.95
	static let hoverScale: CGFloat = 1.025
	/// Gentler press feedback for large tiles, rows, and dense pills.
	static let subtlePressedScale: CGFloat = 0.97
	static let subtleHoverScale: CGFloat = 1.01
	static let breathingCycle: TimeInterval = 3.2

	static func animation(_ curve: Curve, reduceMotion: Bool) -> Animation? {
		reduceMotion ? nil : curve.animation
	}

	/// A quiet opacity-only fade that keeps state changes legible under Reduce Motion.
	static func fade(reduceMotion: Bool) -> Animation {
		reduceMotion ? .easeInOut(duration: 0.15) : Curve.state.animation
	}

	/// Staggered entry for the sibling at `index`.
	static func staggered(_ curve: Curve, index: Int, reduceMotion: Bool) -> Animation? {
		guard !reduceMotion else { return nil }
		return curve.animation.delay(Double(max(index, 0)) * staggerStep)
	}
}

/// Blur, scale, offset, and opacity combined so content materialises instead of popping in.
private struct MaterializeModifier: ViewModifier {
	let blur: CGFloat
	let scale: CGFloat
	let offsetY: CGFloat
	let opacity: Double
	let anchor: UnitPoint

	func body(content: Content) -> some View {
		content
			.blur(radius: blur)
			.scaleEffect(scale, anchor: anchor)
			.offset(y: offsetY)
			.opacity(opacity)
	}
}

extension AnyTransition {
	/// Reveals content from a soft, slightly smaller state. Reduce Motion keeps only opacity.
	static func materialize(
		reduceMotion: Bool,
		scale: CGFloat = 0.94,
		blur: CGFloat = 6,
		offsetY: CGFloat = 0,
		anchor: UnitPoint = .center
	) -> AnyTransition {
		guard !reduceMotion else { return .opacity }
		return .modifier(
			active: MaterializeModifier(
				blur: blur,
				scale: scale,
				offsetY: offsetY,
				opacity: 0,
				anchor: anchor
			),
			identity: MaterializeModifier(
				blur: 0,
				scale: 1,
				offsetY: 0,
				opacity: 1,
				anchor: anchor
			)
		)
	}
}
