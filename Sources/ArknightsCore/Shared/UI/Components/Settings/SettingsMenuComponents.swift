// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// An accent glass chip that stands in for `Picker`'s stock menu-button chrome, so option
/// pickers read as the same interaction language as the landing page's region switcher
/// rather than a default AppKit control.
package struct GlassMenuPicker<Value: Hashable>: View {
	let selection: Binding<Value>
	let options: [(value: Value, title: String)]
	var isDisabled = false
	/// Overrides an option's displayed text inside the open menu only, leaving `title` as the
	/// collapsed button's label — lets a caller show detail (e.g. a result count) that's only
	/// worth the width once the list is actually open.
	var listTitle: (Value) -> String? = { _ in nil }
	var dividerBefore: (Value) -> Bool = { _ in false }
	/// Additional menu content appended after the plain option list — e.g. a submenu that
	/// doesn't itself change `selection`.
	var trailingMenuItems: () -> AnyView = { AnyView(EmptyView()) }

	package init(
		selection: Binding<Value>,
		options: [(value: Value, title: String)],
		isDisabled: Bool = false,
		listTitle: @escaping (Value) -> String? = { _ in nil },
		dividerBefore: @escaping (Value) -> Bool = { _ in false },
		trailingMenuItems: @escaping () -> AnyView = { AnyView(EmptyView()) }
	) {
		self.selection = selection
		self.options = options
		self.isDisabled = isDisabled
		self.listTitle = listTitle
		self.dividerBefore = dividerBefore
		self.trailingMenuItems = trailingMenuItems
	}

	package var body: some View {
		GlassCapsuleMenu(isDisabled: isDisabled) {
			optionButtons
			trailingMenuItems()
		} label: {
			Text(currentTitle)
		}
	}

	private var optionButtons: some View {
		ForEach(options, id: \.value) { option in
			if dividerBefore(option.value) { Divider() }
			Button {
				selection.wrappedValue = option.value
			} label: {
				let title = listTitle(option.value) ?? option.title
				if option.value == selection.wrappedValue {
					Label(title, systemImage: "checkmark")
				} else {
					Text(title)
				}
			}
		}
	}

	private var currentTitle: String {
		options.first(where: { $0.value == selection.wrappedValue })?.title ?? ""
	}
}

package struct GlassActionMenu<Content: View>: View {
	let title: String
	let systemImage: String
	var isDisabled = false
	@ViewBuilder package let content: Content

	package init(
		title: String,
		systemImage: String,
		isDisabled: Bool = false,
		@ViewBuilder content: () -> Content
	) {
		self.title = title
		self.systemImage = systemImage
		self.isDisabled = isDisabled
		self.content = content()
	}

	package var body: some View {
		GlassCapsuleMenu(isDisabled: isDisabled) {
			content
		} label: {
			Image(systemName: systemImage)
				.accessibilityHidden(true)
			Text(title)
		}
	}
}

private struct GlassCapsuleMenu<Items: View, Label: View>: View {
	@Environment(\.launcherTheme) private var theme
	@State private var isHovering = false
	let isDisabled: Bool
	@ViewBuilder let items: Items
	@ViewBuilder let label: Label

	var body: some View {
		Menu {
			items
		} label: {
			HStack(spacing: LauncherTokens.Spacing.control) {
				label
					.monospacedDigit()
					.foregroundStyle(theme.textPrimary)
				Image(systemName: "chevron.up.chevron.down")
					.font(LauncherTokens.Typography.menuChevron)
					.foregroundStyle(theme.accentInk)
					.frame(width: 16, height: 16)
					.background {
						Color.clear.adaptiveGlassEffect(
							tint: theme.accentGlassTint,
							borderTint: theme.accentGlassStroke,
							in: Circle(),
							showsBorder: true
						)
					}
					.accessibilityHidden(true)
			}
			.padding(.leading, LauncherTokens.Spacing.content)
			.padding(.trailing, LauncherTokens.Spacing.compact)
			// 16 pt chip plus 2 x 6 pt matches the button: 12 pt line plus 2 x 6 pt.
			.padding(.vertical, 6)
			.background {
				Capsule().fill(theme.controlFill)
				Capsule().fill(theme.hoverTint)
					.opacity(isHovering ? 1 : 0)
					.launcherAnimation(isHovering ? .hoverIn : .hoverOut, value: isHovering)
				Capsule().strokeBorder(theme.controlStroke, lineWidth: 1)
			}
			.contentShape(Capsule())
			.opacity(isDisabled ? 0.4 : 1)
			.onHover { isHovering = $0 }
		}
		.menuStyle(.button)
		// On macOS the label takes the menu font unless the font is set on the Menu itself.
		.font(LauncherTokens.Typography.control)
		.buttonStyle(.plain)
		.keyboardFocusIndicator(in: Capsule())
		.disabled(isDisabled)
	}
}

package struct QuietLink: View {
	let title: String
	let destination: URL

	package init(title: String, destination: URL) {
		self.title = title
		self.destination = destination
	}

	@State private var isHovering = false

	package var body: some View {
		Link(title, destination: destination)
			.foregroundStyle(isHovering ? Color.primary : Color.secondary)
			.underline(isHovering)
			.onHover { isHovering = $0 }
	}
}

package struct DocumentLinkRow: View {
	let title: String
	let systemImage: String
	let action: () -> Void

	package init(
		title: String,
		systemImage: String,
		action: @escaping () -> Void
	) {
		self.title = title
		self.systemImage = systemImage
		self.action = action
	}

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.launcherTheme) private var theme
	@State private var isHovering = false

	package var body: some View {
		Button(action: action) {
			HStack {
				Label(title, systemImage: systemImage)
				Spacer()
				Image(systemName: "chevron.right")
					.font(.caption.weight(.medium))
					.foregroundStyle(.tertiary)
					.accessibilityHidden(true)
			}
			.foregroundStyle(isHovering ? theme.accentFill : .primary)
			.padding(.vertical, LauncherTokens.Spacing.content)
			.padding(.horizontal, LauncherTokens.Spacing.control)
			.background(
				isHovering ? theme.accentFill.opacity(0.08) : .clear,
				in: .rect(cornerRadius: LauncherTokens.Radius.control)
			)
			.contentShape(.rect)
			.animation(
				LauncherMotion.animation(.hover, reduceMotion: reduceMotion), value: isHovering)
		}
		.buttonStyle(ActionPressStyle(intensity: .pressOnly))
		.keyboardFocusIndicator(in: RoundedRectangle(cornerRadius: LauncherTokens.Radius.control))
		.onHover { isHovering = $0 }
	}
}
