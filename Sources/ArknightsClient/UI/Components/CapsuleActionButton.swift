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
		_ title: String,
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

	init(
		title: String,
		systemImage: String? = nil,
		tone: CapsuleActionTone,
		presentation: CapsuleActionPresentation = .standard,
		role: ButtonRole? = nil,
		showsTitle: Bool = true,
		action: @escaping () -> Void
	) {
		self.init(
			title,
			systemImage: systemImage,
			tone: tone,
			presentation: presentation,
			role: role,
			showsTitle: showsTitle,
			action: action
		)
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
		.buttonStyle(CapsuleActionPressStyle())
		.opacity(isEnabled ? 1 : 0.55)
	}
}

private struct CapsuleActionPressStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.opacity(configuration.isPressed ? 0.72 : 1)
			.scaleEffect(configuration.isPressed ? 0.98 : 1)
			.animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
				.font(.system(size: 12, weight: .semibold))
				.foregroundStyle(tint)
				.padding(.horizontal, 11)
				.padding(.vertical, 6)
				.contentShape(Capsule())
				.background(tint.opacity(0.12), in: Capsule())
				.overlay {
					Capsule().strokeBorder(tint.opacity(0.18)).allowsHitTesting(false)
				}
		}
	}

	private func standardSurface(_ content: Content) -> some View {
		content
			.foregroundStyle(tint)
			.padding(.horizontal, standardHorizontalPadding)
			.padding(.vertical, standardVerticalPadding)
			.contentShape(Capsule())
			.adaptiveGlassEffect(tint: tint.opacity(0.1), in: Capsule())
			.overlay {
				Capsule().strokeBorder(tint.opacity(0.2)).allowsHitTesting(false)
			}
	}

	@ViewBuilder
	private func compactSurface(_ content: Content) -> some View {
		if #available(macOS 26, *) {
			content
				.font(.system(size: 12, weight: .semibold))
				.foregroundStyle(tint)
				.padding(.horizontal, 10)
				.padding(.vertical, 5)
				.contentShape(Capsule())
				.glassEffect(.regular.tint(tint.opacity(0.13)), in: .capsule)
		} else {
			content
				.font(.system(size: 12, weight: .semibold))
				.foregroundStyle(tint)
				.padding(.horizontal, 10)
				.padding(.vertical, 5)
				.contentShape(Capsule())
				.background(tint.opacity(0.13), in: Capsule())
				.background(.ultraThinMaterial, in: Capsule())
				.overlay {
					Capsule().strokeBorder(tint.opacity(0.18)).allowsHitTesting(false)
				}
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
