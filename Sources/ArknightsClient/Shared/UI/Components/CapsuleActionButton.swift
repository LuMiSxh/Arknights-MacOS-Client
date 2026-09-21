// SPDX-License-Identifier: MPL-2.0

import SwiftUI

enum CapsuleActionTone {
	case accent(Color)
	case neutral
	case warning
	case danger

	var color: Color {
		switch self {
		case .accent(let color): color
		case .neutral: LauncherVisuals.controlTint
		case .warning: LauncherVisuals.warning
		case .danger: LauncherVisuals.dangerForeground
		}
	}

	var surfaceColor: Color {
		switch self {
		case .accent(let color): color
		case .neutral: LauncherVisuals.controlTint
		case .warning: LauncherVisuals.warning
		case .danger: LauncherVisuals.danger
		}
	}

	func foregroundColor(for contrast: ColorSchemeContrast) -> Color {
		let color = color
		if case .danger = self, contrast == .increased {
			return Color(red: 1, green: 0.55, blue: 0.60)
		}
		return color
	}

	func disabledColor(for contrast: ColorSchemeContrast) -> Color {
		let opacity = contrast == .increased ? 0.52 : 0.44
		switch self {
		case .accent(let color): return color.opacity(opacity)
		case .neutral: return Color.white.opacity(contrast == .increased ? 0.52 : 0.36)
		case .warning: return LauncherVisuals.warning.opacity(opacity)
		case .danger: return LauncherVisuals.dangerForeground.opacity(opacity)
		}
	}
}

enum CapsuleActionPresentation {
	case standard
	case compact
	case hud
}

enum CapsuleActionLabelMotion: Equatable {
	case none
	case primary
}

/// A text action whose visible capsule and interactive label always share the same bounds.
struct CapsuleActionButton: View {
	let title: String
	var systemImage: String?
	let tone: CapsuleActionTone
	var presentation = CapsuleActionPresentation.standard
	var role: ButtonRole?
	var showsTitle = true
	var labelMotion = CapsuleActionLabelMotion.none
	let action: () -> Void

	@Environment(\.controlSize) private var controlSize
	@Environment(\.isEnabled) private var isEnabled
	@Environment(\.colorSchemeContrast) private var contrast
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	init(
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

	var body: some View {
		Button(role: role, action: action) {
			HStack(spacing: 6) {
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
			.fontWeight(.semibold)
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
		return reduceMotion ? .opacity : .symbolEffect(.replace)
	}

	private var labelAnimation: Animation? {
		guard labelMotion == .primary, !reduceMotion else { return nil }
		return .easeInOut(duration: LauncherVisuals.Motion.primaryAction)
	}

	private var titleContentTransition: ContentTransition {
		labelMotion == .primary ? .opacity : .identity
	}

	private var foregroundTint: Color {
		isEnabled ? tone.foregroundColor(for: contrast) : tone.disabledColor(for: contrast)
	}

	private var surfaceTint: Color {
		tone.surfaceColor
	}
}

private struct CapsuleActionLabelModifier: ViewModifier {
	let foreground: Color
	let disabledForeground: Color
	let surfaceTint: Color
	let presentation: CapsuleActionPresentation
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
				.font(.caption.weight(.semibold))
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
			.font(.caption.weight(.semibold))
			.adaptiveControlForeground(foreground, disabledTint: disabledForeground)
			.padding(.horizontal, LauncherVisuals.Control.compactHorizontalPadding)
			.padding(.vertical, LauncherVisuals.Control.compactVerticalPadding)
			.contentShape(Capsule())
			.adaptiveControlSurface(tint: surfaceTint, in: Capsule())
	}

	private var standardHorizontalPadding: CGFloat {
		switch controlSize {
		case .mini: 7
		case .small: 9
		case .large, .extraLarge: 16
		default: LauncherVisuals.Control.standardHorizontalPadding
		}
	}

	private var standardVerticalPadding: CGFloat {
		switch controlSize {
		case .mini: 3
		case .small: 4
		case .large, .extraLarge: 8
		default: LauncherVisuals.Control.standardVerticalPadding
		}
	}
}
