// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Shared launcher motion curves. Views pick a semantic curve instead of a raw duration so
/// press, morph, and presentation timing stays consistent across features. Every
/// curve resolves to `nil` under Reduce Motion; callers that still need a state change to
/// read as a change use `fade(reduceMotion:)`.
package enum LauncherMotion {
	package enum Curve {
		/// Immediate, critically damped response while a control is held down.
		case press
		/// Springy settle after a press ends.
		case release
		/// Hover lift and pointer highlights.
		case hover
		/// Structural layout changes such as appearing controls, status swaps, and content
		/// revealed inside an already visible surface.
		case state
		/// Primary action shape and label morphing between operations.
		case morph
		/// Popups, overlays, and HUD pill expansion entering the window.
		case present
		/// Popups and overlays leaving the window; faster than presentation.
		case dismiss
		/// Artwork, wordmark, and theme crossfades.
		case crossfade
		/// Selection state changes in lists and segmented controls.
		case select
		/// Page and step transitions.
		case page
		/// Determinate progress fill changes.
		case progress
		/// Dimming backdrop behind popups.
		case backdrop
		/// Expanding ripple on completion.
		case ripple
		/// Quick ease-in as an element settles out.
		case settle
		/// Disclosure of inline detail content.
		case disclosure

		package var animation: Animation {
			switch self {
			case .press: .spring(duration: 0.20, bounce: 0)
			case .release: .spring(duration: 0.46, bounce: 0.42)
			case .hover: .spring(duration: 0.32, bounce: 0.22)
			case .state: .spring(duration: 0.38, bounce: 0.16)
			case .morph: .spring(duration: 0.52, bounce: 0.30)
			case .present: .spring(duration: 0.50, bounce: 0.24)
			case .dismiss: .spring(duration: 0.24, bounce: 0)
			case .crossfade: .easeInOut(duration: 0.48)
			case .select: .easeInOut(duration: 0.16)
			case .page: .easeInOut(duration: 0.22)
			case .progress: .linear(duration: 0.20)
			case .backdrop: .easeOut(duration: 0.24)
			case .ripple: .easeOut(duration: 0.9)
			case .settle: .easeIn(duration: 0.18)
			case .disclosure: .snappy(duration: 0.3, extraBounce: 0)
			}
		}
	}

	/// Looping and one-shot durations shared by decorative motion.
	package enum Cycle {
		static let breathing: TimeInterval = 3.2
		package static let completionFeedback: Duration = .milliseconds(400)
		static let progressSweepFadeIn = 0.12
		static let progressSweepTravel = 1.40
		static let progressSweepFadeOut = 0.25
		static let progressSweepPause = 0.55
		static let indeterminateOrbitLaps = 2.0
		static let indeterminateGlintLength = 0.14
	}

	/// Delay between siblings that enter together, such as HUD pills.
	static let staggerStep = 0.045
	package static let pressedScale: CGFloat = 0.95
	package static let hoverScale: CGFloat = 1.025
	/// Gentler press feedback for large tiles, rows, and dense pills.
	static let subtlePressedScale: CGFloat = 0.97
	static let subtleHoverScale: CGFloat = 1.01
	package static func animation(_ curve: Curve, reduceMotion: Bool) -> Animation? {
		reduceMotion ? nil : curve.animation
	}

	/// A quiet opacity-only fade that keeps state changes legible under Reduce Motion.
	package static func fade(reduceMotion: Bool) -> Animation {
		reduceMotion ? .easeInOut(duration: 0.15) : Curve.state.animation
	}

	/// Staggered entry for the sibling at `index`.
	package static func staggered(_ curve: Curve, index: Int, reduceMotion: Bool) -> Animation? {
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
	package static func materialize(
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
