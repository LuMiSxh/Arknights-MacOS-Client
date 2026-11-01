// SPDX-License-Identifier: MPL-2.0

import SwiftUI

package enum CapsuleActionTone {
	case accent(Color)
	case neutral
	case warning
	case danger

	func color(in palette: LauncherPalette) -> Color {
		switch self {
		case .accent(let color): color
		case .neutral: palette.controlTint
		case .warning: LauncherVisuals.warning
		case .danger: LauncherVisuals.dangerForeground
		}
	}

	func surfaceColor(in palette: LauncherPalette) -> Color {
		switch self {
		case .accent(let color): color
		case .neutral: palette.controlTint
		case .warning: LauncherVisuals.warning
		case .danger: LauncherVisuals.danger
		}
	}

	func foregroundColor(for contrast: ColorSchemeContrast, in palette: LauncherPalette) -> Color {
		if case .danger = self, contrast == .increased {
			return LauncherVisuals.dangerForegroundHighContrast
		}
		return color(in: palette)
	}

	func disabledColor(for contrast: ColorSchemeContrast) -> Color {
		let opacity = LauncherVisuals.Control.disabledForegroundOpacity(for: contrast)
		switch self {
		case .accent(let color): return color.opacity(opacity)
		case .neutral:
			return Color.white.opacity(
				LauncherVisuals.Control.disabledNeutralForegroundOpacity(for: contrast)
			)
		case .warning: return LauncherVisuals.warning.opacity(opacity)
		case .danger: return LauncherVisuals.dangerForeground.opacity(opacity)
		}
	}
}

package enum CapsuleActionPresentation {
	case standard
	case compact
	case hud
}

package enum CapsuleActionLabelMotion: Equatable {
	case none
	case primary
}

package struct CapsuleActionButton: View {
	let title: String
	var systemImage: String?
	let tone: CapsuleActionTone
	package var presentation = CapsuleActionPresentation.standard
	var role: ButtonRole?
	var showsTitle = true
	var labelMotion = CapsuleActionLabelMotion.none
	let action: () -> Void

	@Environment(\.controlSize) private var controlSize
	@Environment(\.isEnabled) private var isEnabled
	@Environment(\.colorSchemeContrast) private var contrast
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	package init(
		title: String,
		systemImage: String? = nil,
		tone: CapsuleActionTone,
		presentation: CapsuleActionPresentation = .standard,
		role: ButtonRole? = nil,
		showsTitle: Bool = true,
		labelMotion: CapsuleActionLabelMotion = .none,
		action: @escaping () -> Void
	) {
		self.title = title
		self.systemImage = systemImage
		self.tone = tone
		self.presentation = presentation
		self.role = role
		self.showsTitle = showsTitle
		self.labelMotion = labelMotion
		self.action = action
	}

	package var body: some View {
		Button(role: role, action: action) {
			HStack(spacing: 8) {
				if let systemImage {
					Image(systemName: systemImage)
						.contentTransition(labelContentTransition)
						.animation(labelAnimation, value: systemImage)
						.accessibilityHidden(true)
				}
				if showsTitle {
					Text(title)
						.contentTransition(titleContentTransition)
						.animation(labelAnimation, value: title)
				}
			}
			.accessibilityLabel(title)
			.fontWeight(.medium)
			.modifier(
				CapsuleActionLabelModifier(
					foreground: foregroundTint,
					disabledForeground: tone.disabledColor(for: contrast),
					surfaceTint: surfaceTint,
					presentation: presentation,
					controlSize: controlSize
				)
			)
		}
		.buttonStyle(ActionPressStyle())
		.keyboardFocusIndicator(in: Capsule())
	}

	private var labelContentTransition: ContentTransition {
		guard labelMotion == .primary else { return .identity }
		guard !reduceMotion else { return .opacity }
		return .symbolEffect(ReplaceSymbolEffect.replace)
	}

	private var labelAnimation: Animation? {
		guard labelMotion == .primary else { return nil }
		return LauncherMotion.animation(.morph, reduceMotion: reduceMotion)
	}

	@Environment(\.launcherPalette) private var palette

	private var titleContentTransition: ContentTransition {
		labelMotion == .primary ? .opacity : .identity
	}

	private var foregroundTint: Color {
		isEnabled
			? tone.foregroundColor(for: contrast, in: palette) : tone.disabledColor(for: contrast)
	}

	private var surfaceTint: Color {
		tone.surfaceColor(in: palette)
	}
}

private struct CapsuleActionLabelModifier: ViewModifier {
	let foreground: Color
	let disabledForeground: Color
	let surfaceTint: Color
	package let presentation: CapsuleActionPresentation
	let controlSize: ControlSize

	@ViewBuilder
	func body(content: Content) -> some View {
		switch presentation {
		case .standard:
			standardSurface(content)
		case .compact:
			compactSurface(content)
		case .hud:
			content
				.font(.caption.weight(.medium))
				.adaptiveControlForeground(foreground, disabledTint: disabledForeground)
				.padding(.horizontal, LauncherVisuals.Control.hudHorizontalPadding)
				.padding(.vertical, LauncherVisuals.Control.hudVerticalPadding)
				.contentShape(Capsule())
				.adaptiveControlSurface(tint: surfaceTint, in: Capsule())
		}
	}

	private func standardSurface(_ content: Content) -> some View {
		content
			.padding(.horizontal, standardHorizontalPadding)
			.padding(.vertical, standardVerticalPadding)
			.contentShape(Capsule())
			.adaptiveActionSurface(
				tint: surfaceTint,
				foreground: foreground,
				in: Capsule()
			)
	}

	private func compactSurface(_ content: Content) -> some View {
		content
			.font(.caption.weight(.medium))
			.adaptiveControlForeground(foreground, disabledTint: disabledForeground)
			.padding(.horizontal, LauncherVisuals.Control.compactHorizontalPadding)
			.padding(.vertical, LauncherVisuals.Control.compactVerticalPadding)
			.contentShape(Capsule())
			.adaptiveControlSurface(tint: surfaceTint, in: Capsule())
	}

	private var standardHorizontalPadding: CGFloat {
		switch controlSize {
		case .mini: 8
		case .small: 8
		case .large, .extraLarge: 16
		default: LauncherVisuals.Control.standardHorizontalPadding
		}
	}

	private var standardVerticalPadding: CGFloat {
		switch controlSize {
		case .mini: 4
		case .small: 4
		case .large, .extraLarge: 8
		default: LauncherVisuals.Control.standardVerticalPadding
		}
	}
}
