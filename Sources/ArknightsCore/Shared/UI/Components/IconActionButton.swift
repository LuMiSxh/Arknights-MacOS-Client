// SPDX-License-Identifier: MPL-2.0

import SwiftUI

package struct IconActionButton: View {
	let title: String
	let systemImage: String
	let tone: CapsuleActionTone
	let role: ButtonRole?
	let foreground: Color?
	let surface: ControlSurfacePresentation
	/// Optional surface-only tint for neutral controls, such as the Settings gear over HUD art.
	/// The semantic tone still controls the icon's enabled and disabled foregrounds.
	let surfaceTint: Color?
	let size: CGFloat
	let hitTargetSize: CGFloat
	let action: () -> Void
	@Environment(\.colorSchemeContrast) private var contrast

	package init(
		title: String,
		systemImage: String,
		tone: CapsuleActionTone = .neutral,
		role: ButtonRole? = nil,
		foreground: Color? = nil,
		surface: ControlSurfacePresentation = .neutral,
		surfaceTint: Color? = nil,
		size: CGFloat = LauncherVisuals.Control.iconButtonSize,
		hitTargetSize: CGFloat? = nil,
		action: @escaping () -> Void
	) {
		self.title = title
		self.systemImage = systemImage
		self.tone = tone
		self.role = role
		self.foreground = foreground
		self.surface = surface
		self.surfaceTint = surfaceTint
		self.size = size
		self.hitTargetSize = max(size, hitTargetSize ?? size)
		self.action = action
	}

	package var body: some View {
		Button(role: role, action: action) {
			Image(systemName: systemImage)
				.font(
					.system(
						size: min(
							max(
								size / LauncherVisuals.Control.iconButtonSize
									* LauncherVisuals.Control.iconButtonGlyphSize,
								15
							),
							20
						),
						weight: .medium
					)
				)
				.frame(width: size, height: size)
				.contentShape(Circle())
				.modifier(
					IconActionChrome(
						tone: tone,
						surface: surface,
						surfaceTint: surfaceTint,
						foreground: foreground,
						contrast: contrast
					)
				)
				.accessibilityHidden(true)
		}
		.buttonStyle(ActionPressStyle(intensity: .subtle))
		.frame(minWidth: hitTargetSize, minHeight: hitTargetSize)
		.contentShape(Circle())
		.keyboardFocusIndicator(in: Circle())
		.accessibilityLabel(title)
	}
}

/// Icon chrome: the HUD keeps its smoked glass tint. Other neutral
/// and tone-driven icons use the theme surface.
private struct IconActionChrome: ViewModifier {
	let tone: CapsuleActionTone
	let surface: ControlSurfacePresentation
	let surfaceTint: Color?
	let foreground: Color?
	let contrast: ColorSchemeContrast
	@Environment(\.launcherTheme) private var theme
	@Environment(\.colorScheme) private var colorScheme

	/// Dark HUD glass keeps a smoked tint; light HUD glass uses the theme group fill.
	private var hudSurfaceTint: Color {
		colorScheme == .dark ? theme.sheetSolid.opacity(0.52) : theme.groupFill
	}

	@ViewBuilder
	func body(content: Content) -> some View {
		if surface == .hud || surfaceTint != nil {
			content
				.adaptiveControlSurface(
					tint: surfaceTint
						?? (surface == .hud
							? hudSurfaceTint : tone.surfaceColor(in: theme)),
					presentation: surface,
					isInteractive: true,
					in: Circle()
				)
				.adaptiveControlForeground(
					foreground ?? tone.foregroundColor(in: theme),
					disabledTint: tone.disabledColor(for: contrast, theme: theme)
				)
		} else {
			content
				.themedActionSurface(tone, in: Circle())
				.foregroundStyle(foreground ?? tone.ink(in: theme))
		}
	}
}
