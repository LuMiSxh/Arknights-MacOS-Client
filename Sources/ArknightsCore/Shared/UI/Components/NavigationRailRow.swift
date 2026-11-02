// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// One row of a launcher navigation rail. With an action it is a button with hover and press
/// feedback; without one it is a read-only step that VoiceOver reads as one element.
/// One row of a launcher navigation rail. With an action it is a button with hover and press
/// feedback; without one it is a read-only step that VoiceOver reads as one element.
package struct NavigationRailRow: View {
	@Environment(\.launcherTheme) private var theme
	@State private var isHovering = false
	let title: String
	let systemImage: String
	let isSelected: Bool
	/// Kept for existing call sites; the theme supplies the color.
	let accentColor: Color
	/// Kept for existing call sites; the title always uses the primary text role.
	let isHighlighted: Bool
	let action: (() -> Void)?

	package init(
		title: String,
		systemImage: String,
		isSelected: Bool,
		accentColor: Color,
		isHighlighted: Bool = false,
		action: (() -> Void)? = nil
	) {
		self.title = title
		self.systemImage = systemImage
		self.isSelected = isSelected
		self.accentColor = accentColor
		self.isHighlighted = isHighlighted
		self.action = action
	}

	package var body: some View {
		rail
			.accessibilityLabel(title)
			.accessibilityAddTraits(isSelected ? .isSelected : [])
	}

	@ViewBuilder
	private var rail: some View {
		if let action {
			Button(action: action) {
				content
			}
			.buttonStyle(ActionPressStyle(intensity: .pressOnly))
			.keyboardFocusIndicator(
				in: RoundedRectangle(cornerRadius: LauncherTokens.Radius.railRow)
			)
			.onHover { isHovering = $0 }
		} else {
			content
				.accessibilityElement(children: .combine)
		}
	}

	private var content: some View {
		HStack(spacing: LauncherTokens.Spacing.control) {
			Image(systemName: systemImage)
				.frame(width: 20)
				.symbolRenderingMode(.monochrome)
				.foregroundStyle(isSelected ? theme.accentInk : theme.textSecondary)
				.accessibilityHidden(true)
			Text(title)
				.foregroundStyle(theme.textPrimary)
			Spacer(minLength: 0)
		}
		.padding(.horizontal, 12)
		.frame(height: 32)
		.background {
			RoundedRectangle(cornerRadius: LauncherTokens.Radius.railRow)
				.fill(theme.neutralFill)
				.opacity(isSelected ? 1 : 0)
			RoundedRectangle(cornerRadius: LauncherTokens.Radius.railRow)
				.fill(theme.hoverTint)
				.opacity(isHovering && !isSelected ? 1 : 0)
				.launcherAnimation(isHovering ? .hoverIn : .hoverOut, value: isHovering)
		}
		.overlay(alignment: .leading) {
			Capsule()
				.fill(isSelected ? theme.accentFill : .clear)
				.frame(width: 3, height: 14)
				.padding(.leading, 2)
				.accessibilityHidden(true)
		}
		.launcherAnimation(.state, value: isSelected)
		.contentShape(RoundedRectangle(cornerRadius: LauncherTokens.Radius.railRow))
	}
}
