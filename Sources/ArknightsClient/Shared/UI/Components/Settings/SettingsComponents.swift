// SPDX-License-Identifier: MPL-2.0

import Observation
import SwiftUI

@MainActor
@Observable
final class SettingsFocusCoordinator {
	var focusedID: AnyHashable?
}

private struct SettingsFocusCoordinatorKey: EnvironmentKey {
	static let defaultValue: SettingsFocusCoordinator? = nil
}

extension EnvironmentValues {
	var settingsFocusCoordinator: SettingsFocusCoordinator? {
		get { self[SettingsFocusCoordinatorKey.self] }
		set { self[SettingsFocusCoordinatorKey.self] = newValue }
	}
}

struct SectionPageHeader: View {
	let title: String
	let subtitle: String
	let accentColor: Color
	var fixesSubtitleHeight = false

	var body: some View {
		VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.control) {
			Text(title)
				.font(.largeTitle.bold())
			Text(subtitle)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: fixesSubtitleHeight)
			HStack(spacing: LauncherVisuals.Spacing.control) {
				Rectangle().fill(accentColor).frame(width: 72, height: 3)
				Rectangle().fill(.secondary.opacity(0.28))
					.frame(height: 1)
					.frame(maxWidth: .infinity)
			}
			.padding(.top, LauncherVisuals.Spacing.tight)
		}
	}
}

struct SettingsPage<Content: View>: View {
	let title: String
	let subtitle: String
	let accentColor: Color
	@ViewBuilder let content: Content
	@State private var focusCoordinator = SettingsFocusCoordinator()
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		ScrollViewReader { proxy in
			ScrollView {
				VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.section) {
					SectionPageHeader(title: title, subtitle: subtitle, accentColor: accentColor)
					content
				}
				.padding(.horizontal, LauncherVisuals.Spacing.page)
				.padding(.top, LauncherVisuals.Spacing.page)
				.padding(.bottom, 72)
				.environment(\.settingsFocusCoordinator, focusCoordinator)
			}
			.contentMargins(.top, LauncherVisuals.Spacing.page, for: .scrollIndicators)
			.contentMargins(.bottom, 22, for: .scrollIndicators)
			.scrollIndicators(.automatic)
			.onChange(of: focusCoordinator.focusedID) { _, focusedID in
				guard let focusedID else { return }
				if reduceMotion {
					proxy.scrollTo(focusedID, anchor: .center)
				} else {
					withAnimation(.easeInOut(duration: LauncherVisuals.Motion.selection)) {
						proxy.scrollTo(focusedID, anchor: .center)
					}
				}
			}
		}
	}
}

/// A subtle row separator matching the nav rail's hairline, used instead of the stock
/// `Divider()` inside glass panels so rows read as one soft surface, not a bordered form.
struct SettingsHairline: View {
	var body: some View {
		Rectangle()
			.fill(LauncherVisuals.hairline)
			.frame(height: LauncherVisuals.Spacing.hairline)
	}
}

struct SettingsPanel<Content: View>: View {
	let title: String
	let systemImage: String
	var tone: SettingsPanelTone = .neutral
	@ViewBuilder let content: Content
	@Environment(\.colorSchemeContrast) private var contrast

	var body: some View {
		VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.content) {
			Label(title, systemImage: systemImage)
				.font(.headline)
				.foregroundStyle(tone.color(for: contrast))
				.symbolRenderingMode(.hierarchical)
			content
		}
		.padding(LauncherVisuals.Spacing.panel)
		.frame(maxWidth: .infinity, alignment: .leading)
		.adaptiveGlassEffect(
			tint: nil,
			in: .rect(cornerRadius: LauncherVisuals.Radius.panel),
			showsBorder: false
		)
		.overlay {
			RoundedRectangle(cornerRadius: LauncherVisuals.Radius.panel)
				.strokeBorder(tone.border, lineWidth: LauncherVisuals.Control.borderWidth)
				.allowsHitTesting(false)
		}
	}
}

enum SettingsPanelTone {
	case neutral
	case success
	case warning
	case danger

	var color: Color {
		switch self {
		case .neutral: .primary
		case .success: LauncherVisuals.success
		case .warning: LauncherVisuals.warning
		case .danger: LauncherVisuals.dangerForeground
		}
	}

	func color(for contrast: ColorSchemeContrast) -> Color {
		if case .danger = self, contrast == .increased {
			return Color(red: 1, green: 0.55, blue: 0.60)
		}
		return color
	}

	var border: Color {
		switch self {
		case .neutral: LauncherVisuals.panelBorder
		case .success: LauncherVisuals.success.opacity(0.35)
		case .warning: LauncherVisuals.warning.opacity(0.28)
		case .danger: LauncherVisuals.danger.opacity(0.32)
		}
	}
}

/// Same quiet panel geometry as `SettingsPanel`, reserved for destructive actions.
struct DangerZonePanel<Content: View>: View {
	let title: String
	@ViewBuilder let content: Content

	init(title: String = "Danger Zone", @ViewBuilder content: () -> Content) {
		self.title = title
		self.content = content()
	}

	var body: some View {
		SettingsPanel(title: title, systemImage: "exclamationmark.triangle.fill", tone: .danger) {
			content
		}
	}
}

struct UpdateSettingsRow: View {
	let title: String
	let status: String
	@Binding var isEnabled: Bool
	let isChecking: Bool
	var isDisabled = false
	let accentColor: Color
	var checkTitle = "Check Now"
	let check: () -> Void

	var body: some View {
		SettingsActionRow(title: title, detail: status) {
			HStack(spacing: LauncherVisuals.Spacing.control) {
				SettingsToggle(title, isOn: $isEnabled, accentColor: accentColor)
					.disabled(isDisabled)
				CapsuleActionButton(
					title: checkTitle,
					tone: .accent(accentColor),
					presentation: .compact,
					action: check
				)
				.disabled(isChecking || isDisabled)
			}
		}
	}
}

struct SettingsActionRow<Actions: View>: View {
	let title: String
	let detail: String
	@ViewBuilder let actions: Actions

	var body: some View {
		ViewThatFits(in: .horizontal) {
			HStack(spacing: LauncherVisuals.Spacing.section) {
				label
					.frame(maxWidth: .infinity, alignment: .leading)
					.layoutPriority(1)
				actions.fixedSize(horizontal: true, vertical: false)
			}
			VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.control) {
				label
				HStack {
					Spacer(minLength: 0)
					actions.fixedSize(horizontal: true, vertical: false)
				}
			}
		}
	}

	@ViewBuilder
	private var label: some View {
		VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.compact) {
			Text(title)
			Text(detail)
				.font(.caption)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
		}
	}
}

/// An accent glass chip that stands in for `Picker`'s stock menu-button chrome, so option
/// pickers read as the same interaction language as the landing page's region switcher
/// rather than a default AppKit control.
struct GlassMenuPicker<Value: Hashable>: View {
	let selection: Binding<Value>
	let options: [(value: Value, title: String)]
	let accentColor: Color
	var isDisabled = false
	/// Overrides an option's displayed text inside the open menu only, leaving `title` as the
	/// collapsed button's label — lets a caller show detail (e.g. a result count) that's only
	/// worth the width once the list is actually open.
	var listTitle: (Value) -> String? = { _ in nil }
	/// Additional menu content appended after the plain option list — e.g. a submenu that
	/// doesn't itself change `selection`. Defaults to nothing, so existing callers are unaffected.
	var trailingMenuItems: () -> AnyView = { AnyView(EmptyView()) }

	var body: some View {
		Menu {
			ForEach(options, id: \.value) { option in
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
			trailingMenuItems()
		} label: {
			HStack(spacing: LauncherVisuals.Spacing.tight) {
				Text(currentTitle)
				Image(systemName: "chevron.up.chevron.down")
					.font(.system(size: 9, weight: .bold))
					.accessibilityHidden(true)
			}
			.settingsControlCapsule(tint: accentColor, isDisabled: isDisabled)
		}
		.menuStyle(.button)
		.buttonStyle(.plain)
		.keyboardFocusIndicator(in: Capsule())
		.disabled(isDisabled)
	}

	private var currentTitle: String {
		options.first(where: { $0.value == selection.wrappedValue })?.title ?? ""
	}
}

/// A settings action menu using the same compact capsule treatment as `GlassMenuPicker`.
struct GlassActionMenu<Content: View>: View {
	let title: String
	let systemImage: String
	let accentColor: Color
	var isDisabled = false
	@ViewBuilder let content: Content

	var body: some View {
		Menu {
			content
		} label: {
			HStack(spacing: LauncherVisuals.Spacing.tight) {
				Image(systemName: systemImage)
					.accessibilityHidden(true)
				Text(title)
				Image(systemName: "chevron.up.chevron.down")
					.font(.system(size: 9, weight: .bold))
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
struct AccentLink: View {
	let title: String
	let destination: URL
	let accentColor: Color
	@State private var isHovering = false

	var body: some View {
		Link(title, destination: destination)
			.foregroundStyle(accentColor)
			.underline(isHovering)
			.onHover { isHovering = $0 }
	}
}

/// Same look as `AccentLink`, but for destinations that cost real work to build
/// (e.g. read log files) and must run only on click, not on every view update.
struct AccentActionLink: View {
	let title: String
	let accentColor: Color
	let action: () -> Void
	@State private var isHovering = false

	var body: some View {
		Button(title, action: action)
			.buttonStyle(.plain)
			.keyboardFocusIndicator(in: Capsule())
			.foregroundStyle(accentColor)
			.underline(isHovering)
			.onHover { isHovering = $0 }
	}
}

struct DocumentLinkRow: View {
	let title: String
	let systemImage: String
	let accentColor: Color
	let action: () -> Void
	@State private var isHovering = false

	var body: some View {
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
		}
		.buttonStyle(.plain)
		.keyboardFocusIndicator(in: RoundedRectangle(cornerRadius: LauncherVisuals.Radius.row))
		.onHover { isHovering = $0 }
	}
}
