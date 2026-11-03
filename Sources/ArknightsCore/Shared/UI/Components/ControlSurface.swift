// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Presentation family for shared control surfaces. HUD controls reuse the same dark glass
/// treatment as the launcher HUD while retaining the control's own semantic foreground.
package enum ControlSurfacePresentation: Equatable {
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
	package func adaptiveControlSurface<ControlShape: Shape>(
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
	package func adaptiveControlForeground(
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

	func settingsControlCapsule(tint: Color, isDisabled: Bool = false) -> some View {
		modifier(SettingsControlCapsuleModifier(tint: tint, isDisabled: isDisabled))
	}
}

private struct AdaptiveControlSurfaceModifier<ShapeType: Shape>: ViewModifier {
	let tint: Color
	let isDisabled: Bool
	package let presentation: ControlSurfacePresentation
	let isInteractive: Bool
	let borderOpacity: Double?
	let shape: ShapeType
	@Environment(\.isEnabled) private var environmentIsEnabled
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
	@Environment(\.colorSchemeContrast) private var contrast
	@Environment(\.controlSurfaceScope) private var controlSurfaceScope
	@Environment(\.launcherTheme) private var theme
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
			content.background { neutralMatte }
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
			return theme.controlStroke.opacity(activeBorderOpacity)
		}
		return tint.opacity(activeBorderOpacity)
	}

	/// Under reduced transparency, the opaque sheet tint sits beneath the matte.
	@ViewBuilder
	private var neutralMatte: some View {
		if reduceTransparency {
			shape.fill(theme.sheetTint).overlay { shape.fill(theme.controlFill) }
		} else {
			shape.fill(theme.controlFill)
		}
	}

	private var hoverFill: Color {
		if presentation == .hud {
			return theme.hoverTint
		}
		if chromatic { return tint.opacity(0.05) }
		return theme.hoverTint
	}

	private var disabledSurface: Color {
		if presentation == .hud {
			return reduceTransparency
				? theme.sheetSolid
				: theme.sheetSolid.opacity(LauncherVisuals.Control.hudDisabledSurfaceOpacity)
		}
		if reduceTransparency { return theme.sheetTint }
		return theme.controlFill.opacity(ActionSurfaceMetrics.disabledOpacity)
	}

	private var disabledBorder: Color {
		if presentation == .hud {
			return theme.controlStroke
		}
		if chromatic {
			let opacity =
				contrast == .increased
				? 0.26 : LauncherVisuals.Control.disabledChromaticBorderOpacity
			return tint.opacity(opacity)
		}
		return theme.controlStroke.opacity(ActionSurfaceMetrics.disabledOpacity)
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
			.font(.caption.weight(.medium))
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

/// Disabled controls fade as a whole, so the fill, stroke, and label share one opacity.
private enum ActionSurfaceMetrics {
	static let disabledOpacity = 0.4
}

extension View {
	/// Theme surface for an action tone. Neutral is a matte fill with a hover wash; accent,
	/// danger, and warning are chromatic glass with a matching stroke.
	package func themedActionSurface<ControlShape: Shape>(
		_ tone: CapsuleActionTone,
		in shape: ControlShape
	) -> some View {
		modifier(ThemedActionSurfaceModifier(tone: tone, shape: shape))
	}
}

private struct ThemedActionSurfaceModifier<ShapeType: Shape>: ViewModifier {
	let tone: CapsuleActionTone
	let shape: ShapeType
	@Environment(\.launcherTheme) private var theme
	@Environment(\.isEnabled) private var isEnabled
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
	@State private var isHovering = false

	func body(content: Content) -> some View {
		surface(content)
			.overlay {
				if case .neutral = tone {
					shape
						.fill(theme.hoverTint)
						.opacity(isHovering && isEnabled ? 1 : 0)
						.allowsHitTesting(false)
				}
			}
			.overlay {
				shape
					.stroke(stroke, lineWidth: LauncherVisuals.Control.borderWidth)
					.allowsHitTesting(false)
			}
			.opacity(isEnabled ? 1 : ActionSurfaceMetrics.disabledOpacity)
			.onHover { isHovering = $0 }
			.launcherAnimation(isHovering ? .hoverIn : .hoverOut, value: isHovering)
	}

	@ViewBuilder
	private func surface(_ content: Content) -> some View {
		switch tone {
		case .neutral:
			if reduceTransparency {
				content.background {
					shape.fill(theme.sheetTint).overlay { shape.fill(theme.controlFill) }
				}
			} else {
				content.background { shape.fill(theme.controlFill) }
			}
		case .accent, .danger, .warning:
			content.adaptiveGlassEffect(
				tint: tint, in: shape, showsBorder: false, isInteractive: true)
		}
	}

	private var tint: Color {
		switch tone {
		case .accent: theme.accentGlassTint
		case .danger: theme.dangerGlassTint
		case .warning: theme.warningGlassTint
		case .neutral: theme.controlFill
		}
	}

	private var stroke: Color {
		switch tone {
		case .accent: theme.accentGlassStroke
		case .danger: theme.dangerGlassStroke
		case .warning: theme.warningGlassStroke
		case .neutral: theme.controlStroke
		}
	}
}
