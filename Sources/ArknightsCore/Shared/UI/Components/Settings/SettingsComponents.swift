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

package struct SectionPageHeader: View {
	let title: String
	let subtitle: String
	package let accentColor: Color
	var fixesSubtitleHeight = false
	@Environment(\.launcherTheme) private var theme

	package init(
		title: String,
		subtitle: String,
		accentColor: Color,
		fixesSubtitleHeight: Bool = false
	) {
		self.title = title
		self.subtitle = subtitle
		self.accentColor = accentColor
		self.fixesSubtitleHeight = fixesSubtitleHeight
	}

	package var body: some View {
		VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.control) {
			Text(title)
				.font(.system(size: 22, weight: .medium))
				.foregroundStyle(theme.textPrimary)
			Text(subtitle)
				.font(.system(size: 13))
				.foregroundStyle(theme.textSecondary)
				.fixedSize(horizontal: false, vertical: fixesSubtitleHeight)
			HStack(spacing: LauncherVisuals.Spacing.control) {
				Rectangle().fill(accentColor).frame(width: 72, height: 3)
				Rectangle().fill(theme.hairline)
					.frame(height: 1)
					.frame(maxWidth: .infinity)
			}
			.padding(.top, LauncherVisuals.Spacing.control)
		}
	}
}

package struct SettingsPage<Content: View>: View {
	let title: String
	let subtitle: String
	package let accentColor: Color
	@ViewBuilder package let content: Content

	package init(
		title: String,
		subtitle: String,
		accentColor: Color,
		@ViewBuilder content: () -> Content
	) {
		self.title = title
		self.subtitle = subtitle
		self.accentColor = accentColor
		self.content = content()
	}

	@State private var focusCoordinator = SettingsFocusCoordinator()
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	package var body: some View {
		ScrollViewReader { proxy in
			ScrollView {
				VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.section) {
					SectionPageHeader(title: title, subtitle: subtitle, accentColor: accentColor)
					content
				}
				.padding(.horizontal, LauncherVisuals.Spacing.page)
				.padding(.top, LauncherVisuals.Spacing.page)
				.environment(\.settingsFocusCoordinator, focusCoordinator)
			}
			// The single scroll margin for settings: the indicator stops short of the rounded edge.
			.contentMargins(.vertical, 16, for: .scrollIndicators)
			.scrollIndicators(.visible)
			.onChange(of: focusCoordinator.focusedID) { _, focusedID in
				guard let focusedID else { return }
				if reduceMotion {
					proxy.scrollTo(focusedID, anchor: .center)
				} else {
					withAnimation(LauncherMotion.animation(.select, reduceMotion: reduceMotion)) {
						proxy.scrollTo(focusedID, anchor: .center)
					}
				}
			}
		}
	}
}

/// Marks a `SettingsHairline` so its `SettingsPanel` can drop it from the row list.
private struct SettingsRuleKey: ContainerValueKey {
	static let defaultValue = false
}

/// True inside a `SettingsPanel`, which already insets each child by 12 pt horizontally and 10 pt vertically.
private struct SettingsPanelRowsKey: EnvironmentKey {
	static let defaultValue = false
}

extension ContainerValues {
	fileprivate var settingsRule: Bool {
		get { self[SettingsRuleKey.self] }
		set { self[SettingsRuleKey.self] = newValue }
	}
}

extension EnvironmentValues {
	fileprivate var settingsPanelRows: Bool {
		get { self[SettingsPanelRowsKey.self] }
		set { self[SettingsPanelRowsKey.self] = newValue }
	}
}

/// A subtle row separator matching the nav rail's hairline, used instead of the stock
/// `Divider()` inside glass panels so rows read as one soft surface, not a bordered form.
/// Inside a `SettingsPanel` the panel drops this view and draws the divider itself.
package struct SettingsHairline: View {
	@Environment(\.launcherTheme) private var theme
	package init() {}
	package var body: some View {
		Rectangle()
			.fill(theme.rowDivider)
			.frame(height: LauncherVisuals.Spacing.hairline)
			.containerValue(\.settingsRule, true)
	}
}

package struct SettingsPanel<Content: View>: View {
	let title: String
	// Kept for existing call sites; the group carries no icon.
	let systemImage: String
	var tone: SettingsPanelTone = .neutral
	var isExpanded: Binding<Bool>?
	@ViewBuilder package let content: Content

	package init(
		title: String,
		systemImage: String,
		tone: SettingsPanelTone = .neutral,
		isExpanded: Binding<Bool>? = nil,
		@ViewBuilder content: () -> Content
	) {
		self.title = title
		self.systemImage = systemImage
		self.tone = tone
		self.isExpanded = isExpanded
		self.content = content()
	}

	@Environment(\.colorSchemeContrast) private var contrast
	@Environment(\.launcherTheme) private var theme
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	package var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			header
			if isExpanded?.wrappedValue ?? true {
				VStack(spacing: 0) {
					Group(subviews: content) { subviews in
						// Explicit hairlines are dropped here: the panel draws the one divider between rows.
						let rows = subviews.filter { !$0.containerValues.settingsRule }
						ForEach(rows.indices, id: \.self) { index in
							if index > 0 {
								Rectangle().fill(theme.rowDivider)
									.frame(height: 1)
									.padding(.horizontal, 12)
							}
							rows[index]
								.frame(maxWidth: .infinity, alignment: .leading)
								.padding(.horizontal, 12)
								.padding(.vertical, 10)
						}
					}
				}
				.environment(\.settingsPanelRows, true)
				.launcherSurface(.group)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	@ViewBuilder
	private var header: some View {
		let label = Text(title)
			.font(.system(size: 13, weight: .medium))
			.foregroundStyle(tone == .neutral ? theme.textSecondary : tone.color(for: contrast))
			.padding(.leading, 12)
		if let isExpanded {
			Button {
				withAnimation(LauncherMotion.animation(.state, reduceMotion: reduceMotion)) {
					isExpanded.wrappedValue.toggle()
				}
			} label: {
				HStack {
					label
					Spacer(minLength: 0)
					Image(systemName: "chevron.right")
						.font(.caption.weight(.medium))
						.foregroundStyle(theme.textSecondary)
						.rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
						.accessibilityHidden(true)
				}
				.padding(.trailing, 12)
				.padding(.top, 20)
				.contentShape(.rect)
			}
			.buttonStyle(.plain)
			.keyboardFocusIndicator(
				in: RoundedRectangle(cornerRadius: LauncherVisuals.Radius.control)
			)
			.accessibilityValue(isExpanded.wrappedValue ? "Expanded" : "Collapsed")
		} else {
			label.padding(.top, 20)
		}
	}
}

package enum SettingsPanelTone {
	case neutral
	case success
	case warning
	case danger

	var color: Color {
		return switch self {
		case .neutral: .primary
		case .success: LauncherVisuals.success
		case .warning: LauncherVisuals.warning
		case .danger: LauncherVisuals.dangerForeground
		}
	}

	func color(for contrast: ColorSchemeContrast) -> Color {
		if case .danger = self, contrast == .increased {
			return LauncherVisuals.dangerForegroundHighContrast
		}
		return color
	}

}

package struct DangerZonePanel<Content: View>: View {
	let title: String
	@ViewBuilder package let content: Content

	package init(title: String = "Danger Zone", @ViewBuilder content: () -> Content) {
		self.title = title
		self.content = content()
	}

	package var body: some View {
		SettingsPanel(title: title, systemImage: "exclamationmark.triangle.fill", tone: .danger) {
			content
		}
	}
}

package struct UpdateSettingsRow: View {
	let title: String
	package let status: String
	@Binding package var isEnabled: Bool
	let isChecking: Bool
	var isDisabled = false
	package let check: () -> Void

	package init(
		title: String,
		status: String,
		isEnabled: Binding<Bool>,
		isChecking: Bool,
		isDisabled: Bool = false,
		check: @escaping () -> Void
	) {
		self.title = title
		self.status = status
		self._isEnabled = isEnabled
		self.isChecking = isChecking
		self.isDisabled = isDisabled
		self.check = check
	}

	package var body: some View {
		SettingsActionRow(title: title, detail: status) {
			HStack(spacing: LauncherVisuals.Spacing.control) {
				SettingsToggle(title, isOn: $isEnabled)
					.disabled(isDisabled)
				CapsuleActionButton(
					title: "Check Now",
					tone: .neutral,
					presentation: .compact,
					action: check
				)
				.disabled(isChecking || isDisabled)
			}
		}
	}
}

package struct SettingsActionRow<Actions: View>: View {
	let title: String
	let detail: String?
	var help: String?
	@ViewBuilder package let actions: Actions
	@Environment(\.settingsPanelRows) private var isInSettingsPanel
	@Environment(\.launcherTheme) private var theme

	package init(
		title: String,
		detail: String? = nil,
		help: String? = nil,
		@ViewBuilder actions: () -> Actions
	) {
		self.title = title
		self.detail = detail
		self.help = help
		self.actions = actions()
	}

	package var body: some View {
		ViewThatFits(in: .horizontal) {
			HStack(spacing: LauncherVisuals.Spacing.section) {
				// A small ideal width lets a long detail wrap beside the action instead of dropping below.
				label
					.frame(minWidth: 0, idealWidth: 240, maxWidth: .infinity, alignment: .leading)
					.layoutPriority(1)
				actionGroup
			}
			VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.control) {
				label
				HStack {
					Spacer(minLength: 0)
					actionGroup
				}
			}
		}
		.padding(.horizontal, isInSettingsPanel ? 0 : 12)
		.padding(.vertical, isInSettingsPanel ? 0 : 10)
		.frame(minHeight: 40)
	}

	@ViewBuilder
	private var actionGroup: some View {
		HStack(spacing: LauncherVisuals.Spacing.control) {
			actions.fixedSize(horizontal: true, vertical: false)
		}
	}

	@ViewBuilder
	private var label: some View {
		VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.compact) {
			Text(title)
				.foregroundStyle(theme.textPrimary)
			if let detail {
				Text(detail)
					.font(.caption)
					.foregroundStyle(theme.textSecondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.help(help.map { Text($0) } ?? Text(verbatim: ""))
	}
}
