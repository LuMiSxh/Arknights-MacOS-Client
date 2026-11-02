// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Shared launcher motion curves. Views pick a semantic curve instead of a raw duration so
/// press, morph, and presentation timing stays consistent across features. Every
/// curve resolves to `nil` under Reduce Motion; callers that still need a state change to
/// read as a change use `fade(reduceMotion:)`.
package enum LauncherMotion {
	/// Motion role for a kind of change. State never moves anything; morph always does.
	package enum Role {
		/// Press and release on buttons, rows, and chips.
		case press, release, hoverIn, hoverOut
		/// Color and opacity only: toggle ink, status swaps, inactive window.
		case state
		/// A selection indicator travelling between items.
		case select
		/// A surface changing size or shape.
		case morph
		/// Modals, popovers, and onboarding entering and leaving.
		case present, dismiss

		/// `hops` applies to `select` only: each skipped item adds 40 ms, capped at 0.36 s.
		package func animation(hops: Int = 1) -> Animation {
			switch self {
			case .press: .spring(duration: 0.10, bounce: 0)
			case .release: .spring(duration: 0.26, bounce: 0.10)
			case .hoverIn: .easeOut(duration: 0.12)
			case .hoverOut: .easeOut(duration: 0.20)
			case .state: .timingCurve(0.2, 0, 0, 1, duration: 0.20)
			case .select:
				.spring(duration: min(0.24 + 0.04 * Double(max(hops, 1) - 1), 0.36), bounce: 0)
			case .morph: .spring(duration: 0.44, bounce: 0.08)
			case .present: .spring(duration: 0.34, bounce: 0)
			case .dismiss: .timingCurve(0.4, 0, 1, 1, duration: 0.16)
			}
		}
	}

	package enum Curve {
		case press
		case release
		case hover
		/// Structural layout changes such as appearing controls, status swaps, and content
		/// revealed inside an already visible surface.
		case state
		case morph
		case present
		/// Popups and overlays leaving the window; faster than presentation.
		case dismiss
		case crossfade
		case select
		case page
		case progress
		case backdrop
		case ripple
		case settle
		case disclosure

		package var animation: Animation {
			switch self {
			case .press: Role.press.animation()
			case .release: Role.release.animation()
			case .hover: Role.hoverIn.animation()
			case .state: Role.state.animation()
			case .morph: Role.morph.animation()
			case .present: Role.present.animation()
			case .dismiss: Role.dismiss.animation()
			case .crossfade: Role.state.animation()
			case .select: Role.select.animation(hops: 1)
			case .page: Role.present.animation()
			case .progress: Role.state.animation()
			case .backdrop: Role.present.animation()
			case .ripple: .easeOut(duration: 0.9)
			case .settle: Role.dismiss.animation()
			case .disclosure: Role.morph.animation()
			}
		}
	}

	package enum Cycle {
		/// Period in seconds of the halo pulse and the indeterminate pulse.
		static let pulse: TimeInterval = 3.2
		package static let completionFeedback: Duration = .milliseconds(400)
		/// Progress sweep phase durations in seconds: fade in, travel, fade out, then pause.
		static let progressSweepFadeIn = 0.12
		static let progressSweepTravel = 1.40
		static let progressSweepFadeOut = 0.25
		static let progressSweepPause = 0.55
		static let indeterminateOrbitLaps = 2.0
		static let indeterminateGlintLength = 0.14
	}

	static let staggerStep = 0.045
	static let expandedContentDelay: TimeInterval = 0.06
	static let modalEntranceDelay: TimeInterval = 0.08
	package static let overlayEntranceScale: CGFloat = 0.96
	package static let pressedScale: CGFloat = 0.95
	package static let subtlePressedScale: CGFloat = 0.97
	package static func animation(_ curve: Curve, reduceMotion: Bool) -> Animation? {
		reduceMotion ? nil : curve.animation
	}

	/// Resolves a role for the Reduce Motion setting. Reduce Motion swaps every role for one short fade.
	package static func animation(for role: Role, reduceMotion: Bool, hops: Int = 1) -> Animation {
		reduceMotion ? .easeOut(duration: 0.20) : role.animation(hops: hops)
	}

	package static func fade(reduceMotion: Bool) -> Animation {
		reduceMotion ? .easeInOut(duration: 0.15) : Curve.state.animation
	}

	package static func staggered(_ curve: Curve, index: Int, reduceMotion: Bool) -> Animation? {
		guard !reduceMotion else { return nil }
		return curve.animation.delay(Double(max(index, 0)) * staggerStep)
	}
}

private struct MaterializeModifier: ViewModifier {
	let scale: CGFloat
	let offsetY: CGFloat
	let opacity: Double
	let anchor: UnitPoint

	func body(content: Content) -> some View {
		content
			.scaleEffect(scale, anchor: anchor)
			.offset(y: offsetY)
			.opacity(opacity)
	}
}

extension AnyTransition {
	/// Fades and scales content: `scale` on enter (0.97 by default), 0.98 on exit.
	/// Reduce Motion keeps only opacity. `blur` is ignored; it stays only so existing call
	/// sites compile and should be removed with them.
	package static func materialize(
		reduceMotion: Bool,
		scale: CGFloat = 0.97,
		blur: CGFloat = 0,
		offsetY: CGFloat = 0,
		anchor: UnitPoint = .center
	) -> AnyTransition {
		guard !reduceMotion else { return .opacity }
		let identity = MaterializeModifier(scale: 1, offsetY: 0, opacity: 1, anchor: anchor)
		return .asymmetric(
			insertion: .modifier(
				active: MaterializeModifier(
					scale: scale, offsetY: offsetY, opacity: 0, anchor: anchor),
				identity: identity
			),
			removal: .modifier(
				active: MaterializeModifier(
					scale: 0.98, offsetY: offsetY, opacity: 0, anchor: anchor),
				identity: identity
			)
		)
	}
}

extension View {
	/// Animates `value` with a motion role. Reads Reduce Motion itself, so callers cannot skip it.
	package func launcherAnimation<V: Equatable>(_ role: LauncherMotion.Role, value: V) -> some View
	{
		modifier(LauncherRoleAnimation(role: role, value: value))
	}
}

private struct LauncherRoleAnimation<V: Equatable>: ViewModifier {
	let role: LauncherMotion.Role
	let value: V
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	func body(content: Content) -> some View {
		content.animation(
			LauncherMotion.animation(for: role, reduceMotion: reduceMotion), value: value)
	}
}

/// Runs `body` in an animation for `role`, or in the Reduce Motion fade.
package func withLauncherAnimation<Result>(
	_ role: LauncherMotion.Role,
	reduceMotion: Bool,
	hops: Int = 1,
	_ body: () throws -> Result
) rethrows -> Result {
	try withAnimation(
		LauncherMotion.animation(for: role, reduceMotion: reduceMotion, hops: hops), body)
}
