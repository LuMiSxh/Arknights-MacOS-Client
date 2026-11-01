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
	@Environment(\.launcherPalette) private var palette
	let isDisabled: Bool
	@ViewBuilder let items: Items
	@ViewBuilder let label: Label

	var body: some View {
		Menu {
			items
		} label: {
			HStack(spacing: LauncherVisuals.Spacing.control) {
				label
				Image(systemName: "chevron.up.chevron.down")
					.font(LauncherVisuals.Typography.menuChevron)
					.accessibilityHidden(true)
			}
			.settingsControlCapsule(tint: palette.controlOn, isDisabled: isDisabled)
		}
		.menuStyle(.button)
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
					.font(.caption.weight(.medium))
					.foregroundStyle(.tertiary)
					.accessibilityHidden(true)
			}
			.foregroundStyle(isHovering ? accentColor : .primary)
			.padding(.vertical, LauncherVisuals.Spacing.content)
			.padding(.horizontal, LauncherVisuals.Spacing.control)
			.background(
				isHovering ? accentColor.opacity(0.08) : .clear,
				in: .rect(cornerRadius: LauncherVisuals.Radius.control)
			)
			.contentShape(.rect)
			.animation(
				LauncherMotion.animation(.hover, reduceMotion: reduceMotion), value: isHovering)
		}
		.buttonStyle(ActionPressStyle(intensity: .pressOnly))
		.keyboardFocusIndicator(in: RoundedRectangle(cornerRadius: LauncherVisuals.Radius.control))
		.onHover { isHovering = $0 }
	}
}
