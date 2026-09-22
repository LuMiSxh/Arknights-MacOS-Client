// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Presentation family for shared control surfaces. HUD controls reuse the same dark glass
/// treatment as the launcher HUD while retaining the control's own semantic foreground.
enum ControlSurfacePresentation: Equatable {
	case neutral
	case hud
}

private struct ControlSurfaceScopeKey: EnvironmentKey {
	static let defaultValue = ControlSurfacePresentation.neutral
}

extension EnvironmentValues {
	var controlSurfaceScope: ControlSurfacePresentation {
		get { self[ControlSurfaceScopeKey.self] }
		set { self[ControlSurfaceScopeKey.self] = newValue }
	}
}

extension View {
	/// Applies the shared accent action treatment independently of control geometry.
	func adaptiveActionSurface<ControlShape: Shape>(
		tint: Color,
		foreground: Color? = nil,
		in shape: ControlShape
	) -> some View {
		adaptiveControlSurface(tint: tint, in: shape)
			.adaptiveControlForeground(foreground ?? tint)
	}

	/// Uses a visible neutral matte for secondary controls and a chromatic Glass surface for
	/// actions with a dynamic accent. Disabled controls always use the explicit matte branch.
	func adaptiveControlSurface<ControlShape: Shape>(
		tint: Color,
		isDisabled: Bool = false,
		presentation: ControlSurfacePresentation = .neutral,
		isInteractive: Bool = true,
		borderOpacity: Double? = nil,
		in shape: ControlShape
	) -> some View {
		modifier(
			AdaptiveControlSurfaceModifier(
				tint: tint,
				isDisabled: isDisabled,
				presentation: presentation,
				isInteractive: isInteractive,
				borderOpacity: borderOpacity,
				shape: shape
			)
		)
	}

	/// Uses the readable chromatic foreground only while the control is enabled. Disabled
	/// colors retain their semantic hue and opacity instead of being normalized by contrastTint.
	func adaptiveControlForeground(
		_ tint: Color,
		disabledTint: Color? = nil,
		isDisabled: Bool = false
	) -> some View {
		modifier(
			AdaptiveControlForegroundModifier(
				tint: tint,
				disabledTint: disabledTint,
				isDisabled: isDisabled
			)
		)
	}

	/// Shared compact chrome for Settings actions and menu pickers.
	func settingsControlCapsule(tint: Color, isDisabled: Bool = false) -> some View {
		modifier(SettingsControlCapsuleModifier(tint: tint, isDisabled: isDisabled))
	}
}

private struct AdaptiveControlSurfaceModifier<ShapeType: Shape>: ViewModifier {
	let tint: Color
	let isDisabled: Bool
	let presentation: ControlSurfacePresentation
	let isInteractive: Bool
	let borderOpacity: Double?
	let shape: ShapeType
	@Environment(\.isEnabled) private var environmentIsEnabled
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
	@Environment(\.colorSchemeContrast) private var contrast
	@Environment(\.controlSurfaceScope) private var controlSurfaceScope
	@State private var isHovering = false

	private var isActive: Bool { environmentIsEnabled && !isDisabled }

	@ViewBuilder
	func body(content: Content) -> some View {
		if isActive {
			activeSurface(content)
				.overlay {
					if allowsCustomHover && isHovering {
						shape
							.fill(hoverFill)
							.allowsHitTesting(false)
					}
				}
				.overlay {
					shape
						.stroke(
							activeBorder,
							lineWidth: LauncherVisuals.Control.borderWidth
						)
						.allowsHitTesting(false)
				}
				.onHover { isHovering = allowsCustomHover && $0 }
		} else {
			content
				.background(disabledSurface, in: shape)
				.overlay {
					shape
						.stroke(
							disabledBorder,
							lineWidth: LauncherVisuals.Control.borderWidth
						)
						.allowsHitTesting(false)
				}
				.onHover { _ in isHovering = false }
		}
	}

	@ViewBuilder
	private func activeSurface(_ content: Content) -> some View {
		if presentation == .hud {
			content.adaptiveGlassEffect(
				tint: tint,
				in: shape,
				showsBorder: false,
				isInteractive: allowsGlassInteraction
			)
		} else if chromatic {
			content.adaptiveGlassEffect(
				tint: tint.opacity(activeSurfaceOpacity),
				in: shape,
				showsBorder: false,
				isInteractive: allowsGlassInteraction
			)
		} else {
			content.background(neutralActiveSurface, in: shape)
		}
	}

	private var chromatic: Bool {
		let resolved = tint.resolve(in: EnvironmentValues())
		return max(resolved.red, resolved.green, resolved.blue)
			- min(resolved.red, resolved.green, resolved.blue) > 0.08
	}

	private var allowsCustomHover: Bool {
		isInteractive && controlSurfaceScope != .hud
	}

	private var allowsGlassInteraction: Bool {
		controlSurfaceScope != .hud && (presentation == .neutral || isInteractive)
	}

	private var activeSurfaceOpacity: Double {
		chromatic
			? LauncherVisuals.Control.enabledChromaticSurfaceOpacity
			: LauncherVisuals.Control.enabledNeutralSurfaceOpacity
	}

	private var activeBorderOpacity: Double {
		if let borderOpacity { return borderOpacity }
		if contrast == .increased { return 0.58 }
		if presentation == .hud { return LauncherVisuals.Control.hudBorderOpacity }
		return chromatic
			? LauncherVisuals.Control.enabledChromaticBorderOpacity
			: LauncherVisuals.Control.enabledNeutralBorderOpacity
	}

	private var activeBorder: Color {
		if presentation == .hud {
			return LauncherVisuals.hairline.opacity(activeBorderOpacity)
		}
		return tint.opacity(activeBorderOpacity)
	}

	private var neutralActiveSurface: Color {
		if reduceTransparency { return LauncherVisuals.Control.opaqueNeutralSurface }
		return Color.white.opacity(LauncherVisuals.Control.enabledNeutralSurfaceOpacity)
	}

	private var hoverFill: Color {
		if presentation == .hud {
			return Color.white.opacity(LauncherVisuals.Control.hudHoverSurfaceOpacity)
		}
		if chromatic { return tint.opacity(0.05) }
		return Color.white.opacity(0.04)
	}

	private var disabledSurface: Color {
		if presentation == .hud {
			return reduceTransparency
				? LauncherVisuals.Control.opaqueDisabledSurface
				: Color.black.opacity(LauncherVisuals.Control.hudDisabledSurfaceOpacity)
		}
		if reduceTransparency { return LauncherVisuals.Control.opaqueDisabledSurface }
		return Color.white.opacity(
			chromatic
				? LauncherVisuals.Control.disabledChromaticSurfaceOpacity
				: LauncherVisuals.Control.disabledNeutralSurfaceOpacity
		)
	}

	private var disabledBorder: Color {
		if presentation == .hud {
			return Color.white.opacity(LauncherVisuals.Control.hudDisabledBorderOpacity)
		}
		let opacity =
			contrast == .increased
			? 0.26
			: (chromatic
				? LauncherVisuals.Control.disabledChromaticBorderOpacity
				: LauncherVisuals.Control.disabledNeutralBorderOpacity)
		return (chromatic ? tint : Color.white).opacity(opacity)
	}
}

private struct AdaptiveControlForegroundModifier: ViewModifier {
	let tint: Color
	let disabledTint: Color?
	let isDisabled: Bool
	@Environment(\.isEnabled) private var isEnabled

	func body(content: Content) -> some View {
		if isEnabled && !isDisabled {
			content.adaptiveTintForeground(tint)
		} else {
			content.foregroundStyle(disabledTint ?? tint)
		}
	}
}

private struct SettingsControlCapsuleModifier: ViewModifier {
	let tint: Color
	let isDisabled: Bool
	@Environment(\.colorSchemeContrast) private var contrast

	func body(content: Content) -> some View {
		content
			.font(.caption.weight(.semibold))
			.adaptiveControlForeground(
				tint,
				disabledTint: tint.opacity(
					LauncherVisuals.Control.disabledForegroundOpacity(for: contrast)
				),
				isDisabled: isDisabled
			)
			.padding(.horizontal, LauncherVisuals.Control.compactHorizontalPadding)
			.padding(.vertical, LauncherVisuals.Control.compactVerticalPadding)
			.adaptiveControlSurface(tint: tint, isDisabled: isDisabled, in: Capsule())
			.contentShape(Capsule())
	}
}
