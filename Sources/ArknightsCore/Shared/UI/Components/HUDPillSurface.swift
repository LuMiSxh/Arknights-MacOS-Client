// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// A shared surface for compact HUD pills and their expanded detail panels. Callers own the
/// interactive content insets so Button hit targets stay aligned with the visible surface.
/// A caller that overlays its own border, such as `HUDPillProgressOutline`, passes
/// `showsBorder: false`.
struct HUDPillSurface<Content: View>: View {
	let isExpanded: Bool
	let showsBorder: Bool
	@ViewBuilder package let content: Content
	@Environment(\.launcherTheme) private var theme
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	package init(
		isExpanded: Bool = false,
		showsBorder: Bool = true,
		@ViewBuilder content: () -> Content
	) {
		self.isExpanded = isExpanded
		self.showsBorder = showsBorder
		self.content = content()
	}

	package var body: some View {
		content
			.contentShape(surfaceShape)
			.adaptiveControlSurface(
				tint: colorScheme == .dark ? theme.controlFill : theme.groupFill,
				presentation: .hud,
				isInteractive: false,
				borderOpacity: showsBorder ? LauncherVisuals.Control.hudBorderOpacity : 0,
				in: surfaceShape
			)
			.animation(
				HUDPillMotion.expansionAnimation(reduceMotion: reduceMotion),
				value: isExpanded
			)
			.environment(\.controlSurfaceScope, .hud)
	}

	private var surfaceShape: HUDPillShape {
		HUDPillShape(
			expansion: isExpanded ? 1 : 0,
			expandedCornerRadius: LauncherVisuals.Radius.hudPill
		)
	}

}

private struct HUDPillShape: Shape {
	var expansion: CGFloat
	let expandedCornerRadius: CGFloat

	var animatableData: CGFloat {
		get { expansion }
		set { expansion = newValue }
	}

	func path(in rect: CGRect) -> Path {
		let capsuleRadius = min(rect.width, rect.height) / 2

		let interpolatedRadius =
			capsuleRadius
			+ (expandedCornerRadius - capsuleRadius) * expansion
		let radius = min(max(interpolatedRadius, 0), capsuleRadius)
		return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
	}
}

package enum HUDPillMotion {
	static func progressAnimation(reduceMotion: Bool) -> Animation? {
		LauncherMotion.animation(.progress, reduceMotion: reduceMotion)
	}

	package static func expansionAnimation(reduceMotion: Bool) -> Animation? {
		LauncherMotion.animation(.morph, reduceMotion: reduceMotion)
	}

	package static func expandedContentTransition(reduceMotion: Bool) -> AnyTransition {
		if reduceMotion { return .opacity }
		return .asymmetric(
			insertion: .materialize(
				reduceMotion: false,
				scale: 0.92,
				blur: 8,
				offsetY: 6,
				anchor: .topTrailing
			)
			.animation(
				LauncherMotion.Curve.state.animation.delay(LauncherMotion.expandedContentDelay)
			),
			removal: .materialize(reduceMotion: false, scale: 0.96, blur: 4, anchor: .topTrailing)
				.animation(LauncherMotion.Curve.dismiss.animation)
		)
	}

	package static func chevronTransition(reduceMotion: Bool) -> ContentTransition {
		reduceMotion ? .identity : .symbolEffect(.replace)
	}
}

/// The border and download outline of a progress-bearing HUD surface. Overlay it on a
/// `HUDPillSurface` with `showsBorder: false`. The outline dims the border to 0.5 while it is drawn.
package struct HUDPillProgressOutline: View {
	let progress: Double?
	let isActive: Bool
	let tint: Color
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.launcherTheme) private var theme

	package init(progress: Double?, isActive: Bool, tint: Color) {
		self.progress = progress
		self.isActive = isActive
		self.tint = tint
	}

	package var body: some View {
		Capsule()
			.stroke(
				theme.controlStroke.opacity(
					progress == nil ? LauncherVisuals.Control.hudBorderOpacity : 0.5
				),
				lineWidth: LauncherVisuals.Control.borderWidth
			)
			.overlay {
				CapsuleProgressOutline(
					progress: progress ?? 0,
					tint: tint,
					isGlintActive: isActive,
					track: .clear
				)
				.animation(
					HUDPillMotion.progressAnimation(reduceMotion: reduceMotion),
					value: progress
				)
				.opacity(progress == nil ? 0 : 1)
			}
			.allowsHitTesting(false)
	}
}

extension View {
	package func hudPillSurface(
		isExpanded: Bool = false,
		showsBorder: Bool = true
	) -> some View {
		HUDPillSurface(isExpanded: isExpanded, showsBorder: showsBorder) {
			self
		}
	}
}
