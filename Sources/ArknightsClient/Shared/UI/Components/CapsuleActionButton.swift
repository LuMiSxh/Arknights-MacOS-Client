// SPDX-License-Identifier: MPL-2.0

import SwiftUI

enum CapsuleActionTone {
	case accent(Color)
	case neutral
	case danger

	var color: Color {
		switch self {
		case .accent(let color): color
		case .neutral: LauncherVisuals.controlTint
		case .danger: LauncherVisuals.danger
		}
	}
}

enum CapsuleActionPresentation {
	case standard
	case compact
	case hud
}

/// A text action whose visible capsule and interactive label always share the same bounds.
struct CapsuleActionButton: View {
	let title: String
	var systemImage: String?
	let tone: CapsuleActionTone
	var presentation = CapsuleActionPresentation.standard
	var role: ButtonRole?
	var showsTitle = true
	let action: () -> Void

	@Environment(\.controlSize) private var controlSize
	@Environment(\.isEnabled) private var isEnabled

	init(
		title: String,
		systemImage: String? = nil,
		tone: CapsuleActionTone,
		presentation: CapsuleActionPresentation = .standard,
		role: ButtonRole? = nil,
		showsTitle: Bool = true,
		action: @escaping () -> Void
	) {
		self.title = title
		self.systemImage = systemImage
		self.tone = tone
		self.presentation = presentation
		self.role = role
		self.showsTitle = showsTitle
		self.action = action
	}

	var body: some View {
		Button(role: role, action: action) {
			HStack(spacing: 6) {
				if let systemImage {
					Image(systemName: systemImage)
						.accessibilityHidden(showsTitle)
				}
				if showsTitle {
					Text(title)
				}
			}
			.accessibilityLabel(title)
			.fontWeight(.semibold)
			.modifier(
				CapsuleActionLabelModifier(
					tint: isEnabled ? tone.color : LauncherVisuals.controlTint.opacity(0.55),
					presentation: presentation,
					controlSize: controlSize
				)
			)
		}
		.buttonStyle(ActionPressStyle())
		.keyboardFocusIndicator(in: Capsule())
		.opacity(isEnabled ? 1 : 0.55)
	}
}

private struct CapsuleActionLabelModifier: ViewModifier {
	let tint: Color
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
				.foregroundStyle(tint)
				.padding(.horizontal, 11)
				.padding(.vertical, 6)
				.contentShape(Capsule())
				.adaptiveGlassEffect(tint: tint.opacity(0.12), in: Capsule())
				.overlay {
					Capsule().strokeBorder(tint.opacity(0.18)).allowsHitTesting(false)
				}
		}
	}

	private func standardSurface(_ content: Content) -> some View {
		content
			.padding(.horizontal, standardHorizontalPadding)
			.padding(.vertical, standardVerticalPadding)
			.contentShape(Capsule())
			.adaptiveActionSurface(tint: tint, in: Capsule())
	}

	private func compactSurface(_ content: Content) -> some View {
		content
			.font(.caption.weight(.semibold))
			.foregroundStyle(tint)
			.padding(.horizontal, 10)
			.padding(.vertical, 5)
			.contentShape(Capsule())
			.adaptiveGlassEffect(tint: tint.opacity(0.13), in: Capsule())
			.overlay {
				Capsule().strokeBorder(tint.opacity(0.18)).allowsHitTesting(false)
			}
	}

	private var standardHorizontalPadding: CGFloat {
		switch controlSize {
		case .mini: 7
		case .small: 9
		case .large, .extraLarge: 16
		default: 12
		}
	}

	private var standardVerticalPadding: CGFloat {
		switch controlSize {
		case .mini: 3
		case .small: 4
		case .large, .extraLarge: 8
		default: 6
		}
	}
}
