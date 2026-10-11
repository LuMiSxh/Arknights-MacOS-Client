// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// An accent glass chip that stands in for `Picker`'s stock menu-button chrome, so option
/// pickers read as the same interaction language as the landing page's region switcher
/// rather than a default AppKit control.
package struct GlassMenuPicker<Value: Hashable>: View {
	let selection: Binding<Value>
	let options: [(value: Value, title: String)]
	package let accentColor: Color
	var isDisabled = false
	/// Overrides an option's displayed text inside the open menu only, leaving `title` as the
	/// collapsed button's label — lets a caller show detail (e.g. a result count) that's only
	/// worth the width once the list is actually open.
	var listTitle: (Value) -> String? = { _ in nil }
	/// A header above the options inside the open menu, like "Looks like" in Displays settings.
	var menuTitle: String? = nil
	/// Draws a divider above these options, to set a group of exact choices apart.
	var dividerBefore: (Value) -> Bool = { _ in false }
	/// Additional menu content appended after the plain option list — e.g. a submenu that
	/// doesn't itself change `selection`.
	var trailingMenuItems: () -> AnyView = { AnyView(EmptyView()) }

	package init(
		selection: Binding<Value>,
		options: [(value: Value, title: String)],
		accentColor: Color,
		isDisabled: Bool = false,
		listTitle: @escaping (Value) -> String? = { _ in nil },
		menuTitle: String? = nil,
		dividerBefore: @escaping (Value) -> Bool = { _ in false },
		trailingMenuItems: @escaping () -> AnyView = { AnyView(EmptyView()) }
	) {
		self.selection = selection
		self.options = options
		self.accentColor = accentColor
		self.isDisabled = isDisabled
		self.listTitle = listTitle
		self.menuTitle = menuTitle
		self.dividerBefore = dividerBefore
		self.trailingMenuItems = trailingMenuItems
	}

	package var body: some View {
		Menu {
			if let menuTitle {
				Section(menuTitle) { optionButtons }
			} else {
				optionButtons
			}
			trailingMenuItems()
		} label: {
			HStack(spacing: LauncherVisuals.Spacing.tight) {
				Text(currentTitle)
				Image(systemName: "chevron.up.chevron.down")
					.font(LauncherVisuals.Typography.menuChevron)
					.accessibilityHidden(true)
			}
			.settingsControlCapsule(tint: accentColor, isDisabled: isDisabled)
		}
		.menuStyle(.button)
		.buttonStyle(.plain)
		.keyboardFocusIndicator(in: Capsule())
		.disabled(isDisabled)
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

/// A settings action menu using the same compact capsule treatment as `GlassMenuPicker`.
package struct GlassActionMenu<Content: View>: View {
	let title: String
	let systemImage: String
	package let accentColor: Color
	var isDisabled = false
	@ViewBuilder package let content: Content

	package init(
		title: String,
		systemImage: String,
		accentColor: Color,
		isDisabled: Bool = false,
		@ViewBuilder content: () -> Content
	) {
		self.title = title
		self.systemImage = systemImage
		self.accentColor = accentColor
		self.isDisabled = isDisabled
		self.content = content()
	}

	package var body: some View {
		Menu {
			content
		} label: {
			HStack(spacing: LauncherVisuals.Spacing.tight) {
				Image(systemName: systemImage)
					.accessibilityHidden(true)
				Text(title)
				Image(systemName: "chevron.up.chevron.down")
					.font(LauncherVisuals.Typography.menuChevron)
					.accessibilityHidden(true)
			}
			.settingsControlCapsule(tint: accentColor, isDisabled: isDisabled)
		}
		.menuStyle(.button)
		.buttonStyle(.plain)
		.keyboardFocusIndicator(in: Capsule())
		.disabled(isDisabled)
	}
}

/// A `Link` that underlines on hover instead of sitting there looking unresponsive.
package struct AccentLink: View {
	let title: String
	let destination: URL
	package let accentColor: Color

	package init(title: String, destination: URL, accentColor: Color) {
		self.title = title
		self.destination = destination
		self.accentColor = accentColor
	}

	@State private var isHovering = false

	package var body: some View {
		Link(title, destination: destination)
			.foregroundStyle(accentColor)
			.underline(isHovering)
			.onHover { isHovering = $0 }
	}
}

package struct DocumentLinkRow: View {
	let title: String
	let systemImage: String
	package let accentColor: Color
	let action: () -> Void

	package init(
		title: String,
		systemImage: String,
		accentColor: Color,
		action: @escaping () -> Void
	) {
		self.title = title
		self.systemImage = systemImage
		self.accentColor = accentColor
		self.action = action
	}

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var isHovering = false

	package var body: some View {
		Button(action: action) {
			HStack {
				Label(title, systemImage: systemImage)
				Spacer()
				Image(systemName: "chevron.right")
					.font(.caption.weight(.semibold))
					.foregroundStyle(.tertiary)
					.accessibilityHidden(true)
			}
			.foregroundStyle(isHovering ? accentColor : .primary)
			.padding(.vertical, LauncherVisuals.Spacing.content)
			.padding(.horizontal, LauncherVisuals.Spacing.tight)
			.background(
				isHovering ? accentColor.opacity(0.08) : .clear,
				in: .rect(cornerRadius: LauncherVisuals.Radius.row)
			)
			.contentShape(.rect)
			.animation(
				LauncherMotion.animation(.hover, reduceMotion: reduceMotion), value: isHovering)
		}
		.buttonStyle(ActionPressStyle(intensity: .pressOnly))
		.keyboardFocusIndicator(in: RoundedRectangle(cornerRadius: LauncherVisuals.Radius.row))
		.onHover { isHovering = $0 }
	}
}
