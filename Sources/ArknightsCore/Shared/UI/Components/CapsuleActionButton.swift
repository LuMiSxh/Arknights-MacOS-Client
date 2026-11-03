// SPDX-License-Identifier: MPL-2.0

import SwiftUI

package enum CapsuleActionTone {
	case accent
	case neutral
	case warning
	case danger

	/// Label and icon ink from the theme.
	func ink(in theme: LauncherTheme) -> Color {
		switch self {
		case .accent: theme.accentInk
		case .neutral: theme.textPrimary
		case .warning: theme.warningInk
		case .danger: theme.dangerInk
		}
	}

	/// HUD foreground for an enabled control. Its surface is a tint, so it uses the text inks.
	/// HUD foreground for an enabled control. Its surface is a tint, so it uses the text inks.
	func foregroundColor(in theme: LauncherTheme) -> Color {
		switch self {
		case .accent: theme.accentFill
		case .neutral: theme.textPrimary
		case .warning: theme.warningInk
		case .danger: theme.dangerText
		}
	}

	func surfaceColor(in theme: LauncherTheme) -> Color {
		switch self {
		case .accent: theme.accentFill
		case .neutral: theme.controlFill
		case .warning: theme.warning
		case .danger: theme.dangerSurface
		}
	}

	func disabledColor(for contrast: ColorSchemeContrast, theme: LauncherTheme) -> Color {
		let opacity = LauncherVisuals.Control.disabledForegroundOpacity(for: contrast)
		switch self {
		case .accent: return theme.accentFill.opacity(opacity)
		case .neutral: return theme.textTertiary
		case .warning: return theme.warningInk.opacity(opacity)
		case .danger: return theme.dangerText.opacity(opacity)
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
					let icon = Image(systemName: systemImage)
						.contentTransition(labelContentTransition)
						.animation(labelAnimation, value: systemImage)
						.accessibilityHidden(true)
					if let accentIconInk {
						icon.foregroundStyle(accentIconInk)
					} else {
						icon
					}
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
					tone: tone,
					foreground: foregroundTint,
					disabledForeground: tone.disabledColor(for: contrast, theme: theme),
					surfaceTint: surfaceTint,
					presentation: presentation,
					controlSize: controlSize
				)
			)
		}
		.buttonStyle(ActionPressStyle(intensity: .subtle))
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

	@Environment(\.launcherTheme) private var theme

	private var titleContentTransition: ContentTransition {
		labelMotion == .primary ? .opacity : .identity
	}

	private var foregroundTint: Color {
		guard presentation == .hud else { return tone.ink(in: theme) }
		return isEnabled
			? tone.foregroundColor(in: theme)
			: tone.disabledColor(for: contrast, theme: theme)
	}

	private var surfaceTint: Color {
		tone.surfaceColor(in: theme)
	}

	/// Enabled neutral icons use the accent ink; the title keeps the text role. HUD keeps one ink.
	private var accentIconInk: Color? {
		guard presentation != .hud, isEnabled, case .neutral = tone else { return nil }
		return theme.accentInk
	}
}

private struct CapsuleActionLabelModifier: ViewModifier {
	let tone: CapsuleActionTone
	let foreground: Color
	let disabledForeground: Color
	let surfaceTint: Color
	package let presentation: CapsuleActionPresentation
	let controlSize: ControlSize

	@ViewBuilder
	func body(content: Content) -> some View {
		switch presentation {
		// Compact shares the standard metrics so every capsule in a Settings row has one height.
		case .standard, .compact:
			standardSurface(content)
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
			.font(LauncherTokens.Typography.control)
			.foregroundStyle(foreground)
			.padding(.horizontal, standardHorizontalPadding)
			.padding(.vertical, standardVerticalPadding)
			.contentShape(Capsule())
			.themedActionSurface(tone, in: Capsule())
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
