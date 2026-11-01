// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// One row of a launcher navigation rail. With an action it is a button with hover and press
/// feedback; without one it is a read-only step that VoiceOver reads as one element.
package struct NavigationRailRow: View {
	@Environment(\.launcherPalette) private var palette
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var isHovering = false
	let title: String
	let systemImage: String
	let isSelected: Bool
	let accentColor: Color
	/// Brightens unselected text, for example for a completed setup step.
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
				in: RoundedRectangle(cornerRadius: LauncherVisuals.Radius.control)
			)
			.onHover { isHovering = $0 }
		} else {
			content
				.accessibilityElement(children: .combine)
		}
	}

	private var content: some View {
		HStack(spacing: LauncherVisuals.Spacing.control) {
			RoundedRectangle(cornerRadius: 1)
				.fill(isSelected ? accentColor : .clear)
				.frame(width: 2, height: 16)
				.accessibilityHidden(true)
			Image(systemName: systemImage)
				.frame(width: 16)
				.symbolRenderingMode(.monochrome)
				.accessibilityHidden(true)
			Text(title)
				.fontWeight(.regular)
			Spacer(minLength: 0)
		}
		.foregroundStyle(foregroundStyle)
		.padding(.vertical, 8)
		.padding(.trailing, 12)
		.background(backgroundFill, in: .rect(cornerRadius: LauncherVisuals.Radius.control))
		.contentShape(.rect)
		.frame(minHeight: 40)
		.animation(LauncherMotion.animation(.hover, reduceMotion: reduceMotion), value: isHovering)
	}

	private var foregroundStyle: Color {
		if isSelected { return accentColor }
		return isHighlighted || isHovering ? .primary : .secondary
	}

	private var backgroundFill: Color {
		if isSelected { return LauncherVisuals.selectedNavigationFill(for: accentColor) }
		if isHovering { return palette.navigationHoverFill }
		return .clear
	}
}
