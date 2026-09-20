// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// A shared surface for compact HUD pills and their expanded detail panels. Callers own the
/// interactive content insets so Button hit targets stay aligned with the visible surface.
/// Progress is drawn as an outer contour and never supplies a second full track.
struct HUDPillSurface<Content: View>: View {
	let progress: Double?
	let isProgressActive: Bool
	let isExpanded: Bool
	let tint: Color
	let progressTint: Color
	@ViewBuilder let content: Content
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	init(
		progress: Double? = nil,
		isProgressActive: Bool = false,
		isExpanded: Bool = false,
		tint: Color = LauncherVisuals.hudGlassTint,
		progressTint: Color = LauncherVisuals.controlTint,
		@ViewBuilder content: () -> Content
	) {
		self.progress = progress
		self.isProgressActive = isProgressActive
		self.isExpanded = isExpanded
		self.tint = tint
		self.progressTint = progressTint
		self.content = content()
	}

	var body: some View {
		content
			.contentShape(surfaceShape)
			.adaptiveControlSurface(
				tint: tint,
				presentation: .hud,
				isInteractive: false,
				borderOpacity: progress == nil ? LauncherVisuals.Control.hudBorderOpacity : 0.5,
				in: surfaceShape
			)
			.overlay {
				ZStack {
					CapsuleProgressOutline(
						progress: progress ?? 0,
						tint: progressTint,
						isGlintActive: isProgressActive,
						track: .clear
					)
					.animation(
						HUDPillMotion.progressAnimation(reduceMotion: reduceMotion),
						value: progress
					)
				}
				.opacity(progress == nil || isExpanded ? 0 : 1)
				.allowsHitTesting(false)
			}
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

enum HUDPillMotion {
	static func progressAnimation(reduceMotion: Bool) -> Animation? {
		reduceMotion ? nil : .linear(duration: 0.20)
	}

	static func expansionAnimation(reduceMotion: Bool) -> Animation? {
		reduceMotion
			? nil
			: .snappy(duration: AppConstants.HUD.expansionDuration, extraBounce: 0.04)
	}

	static func expandedContentTransition(reduceMotion: Bool) -> AnyTransition {
		if reduceMotion { return .opacity }
		return .opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing))
	}

	static func chevronTransition(reduceMotion: Bool) -> ContentTransition {
		reduceMotion ? .identity : .symbolEffect(.replace)
	}
}

private struct HUDPillSurfaceModifier: ViewModifier {
	let progress: Double?
	let isProgressActive: Bool
	let isExpanded: Bool
	let tint: Color
	let progressTint: Color

	func body(content: Content) -> some View {
		HUDPillSurface(
			progress: progress,
			isProgressActive: isProgressActive,
			isExpanded: isExpanded,
			tint: tint,
			progressTint: progressTint
		) {
			content
		}
	}
}

extension View {
	/// Applies the shared HUD pill geometry to an existing view.
	func hudPillSurface(
		progress: Double? = nil,
		isProgressActive: Bool = false,
		isExpanded: Bool = false,
		tint: Color = LauncherVisuals.hudGlassTint,
		progressTint: Color = LauncherVisuals.controlTint
	) -> some View {
		modifier(
			HUDPillSurfaceModifier(
				progress: progress,
				isProgressActive: isProgressActive,
				isExpanded: isExpanded,
				tint: tint,
				progressTint: progressTint
			)
		)
	}
}
