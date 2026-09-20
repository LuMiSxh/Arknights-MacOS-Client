// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// A shared icon-only action with the same semantic tone and focus treatment as text actions.
struct IconActionButton: View {
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

	init(
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

	var body: some View {
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
						weight: .semibold
					)
				)
				.frame(width: size, height: size)
				.contentShape(Circle())
				.adaptiveControlSurface(
					tint: surfaceTint
						?? (surface == .hud ? LauncherVisuals.hudGlassTint : tone.surfaceColor),
					presentation: surface,
					isInteractive: true,
					in: Circle()
				)
				.adaptiveControlForeground(
					foreground ?? tone.foregroundColor(for: contrast),
					disabledTint: tone.disabledColor(for: contrast)
				)
				.accessibilityHidden(true)
		}
		.buttonStyle(ActionPressStyle())
		.frame(minWidth: hitTargetSize, minHeight: hitTargetSize)
		.contentShape(Circle())
		.keyboardFocusIndicator(in: Circle())
		.accessibilityLabel(title)
	}
}
