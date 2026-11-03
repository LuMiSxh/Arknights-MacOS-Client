// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// One row of a launcher navigation rail. With an action it is a button with hover and press
/// feedback; without one it is a read-only step that VoiceOver reads as one element.
package struct NavigationRailRow: View {
	@Environment(\.launcherTheme) private var theme
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var isHovering = false
	let title: String
	let systemImage: String
	let isSelected: Bool

	/// Namespace shared by the rows of one rail. When set, the selection indicator slides to the
	/// selected row instead of fading in place. Reduce Motion ignores it.
	let selectionNamespace: Namespace.ID?
	let action: (() -> Void)?

	package init(
		title: String,
		systemImage: String,
		isSelected: Bool,

		selectionNamespace: Namespace.ID? = nil,
		action: (() -> Void)? = nil
	) {
		self.title = title
		self.systemImage = systemImage
		self.isSelected = isSelected

		self.selectionNamespace = selectionNamespace
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

	private var slidingNamespace: Namespace.ID? {
		reduceMotion ? nil : selectionNamespace
	}

	private var content: some View {
		HStack(spacing: LauncherTokens.Spacing.control) {
			Image(systemName: systemImage)
				.frame(width: 20)
				.symbolRenderingMode(.monochrome)
				.foregroundStyle(isSelected ? theme.accentInk : theme.textSecondary)
				.launcherAnimation(.state, value: isSelected)
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
				.selectionIndicator(.fill, isSelected: isSelected, in: slidingNamespace)
			RoundedRectangle(cornerRadius: LauncherTokens.Radius.railRow)
				.fill(theme.hoverTint)
				.opacity(isHovering && !isSelected ? 1 : 0)
				.launcherAnimation(isHovering ? .hoverIn : .hoverOut, value: isHovering)
		}
		.overlay(alignment: .leading) {
			Capsule()
				.fill(theme.accentFill)
				.frame(width: 3, height: 14)
				.selectionIndicator(.tick, isSelected: isSelected, in: slidingNamespace)
				.padding(.leading, 2)
				.accessibilityHidden(true)
		}
		.contentShape(RoundedRectangle(cornerRadius: LauncherTokens.Radius.railRow))
	}
}

/// Identifies the moving parts of a rail selection so matched geometry pairs them across rows.
private enum RailSelectionPart: Hashable {
	case fill, tick
}

extension View {
	/// With a namespace, only the selected row carries the indicator; matched geometry moves it
	/// to the new row. Without one, the indicator stays in place and fades.
	@ViewBuilder
	fileprivate func selectionIndicator(
		_ part: RailSelectionPart, isSelected: Bool, in namespace: Namespace.ID?
	) -> some View {
		if let namespace {
			if isSelected {
				matchedGeometryEffect(id: part, in: namespace)
			}
		} else {
			opacity(isSelected ? 1 : 0)
				.launcherAnimation(.state, value: isSelected)
		}
	}
}
