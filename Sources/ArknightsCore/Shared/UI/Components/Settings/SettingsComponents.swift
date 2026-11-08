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
	var fixesSubtitleHeight = false
	@Environment(\.launcherTheme) private var theme

	package init(
		title: String,
		subtitle: String,
		fixesSubtitleHeight: Bool = false
	) {
		self.title = title
		self.subtitle = subtitle
		self.fixesSubtitleHeight = fixesSubtitleHeight
	}

	package var body: some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
			Text(title)
				.font(LauncherTokens.Typography.pageTitle)
				.foregroundStyle(theme.textPrimary)
			Text(subtitle)
				.font(.body)
				.foregroundStyle(theme.textSecondary)
				.fixedSize(horizontal: false, vertical: fixesSubtitleHeight)
			HStack(spacing: LauncherTokens.Spacing.control) {
				Rectangle().fill(theme.accentFill)
					.frame(
						width: LauncherTokens.Layout.sectionAccentRuleWidth,
						height: LauncherTokens.Layout.sectionAccentRuleHeight)
				Rectangle().fill(theme.hairline)
					.frame(height: 1)
					.frame(maxWidth: .infinity)
			}
			.padding(.top, LauncherTokens.Spacing.control)
		}
	}
}

package struct SettingsPage<Content: View>: View {
	let title: String
	let subtitle: String
	@ViewBuilder package let content: Content

	package init(
		title: String,
		subtitle: String,
		@ViewBuilder content: () -> Content
	) {
		self.title = title
		self.subtitle = subtitle
		self.content = content()
	}

	@State private var focusCoordinator = SettingsFocusCoordinator()
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	package var body: some View {
		ScrollViewReader { proxy in
			ScrollView {
				VStack(alignment: .leading, spacing: LauncherTokens.Spacing.section) {
					SectionPageHeader(title: title, subtitle: subtitle)
					content
				}
				.padding(.horizontal, LauncherTokens.Spacing.page)
				.padding(.top, LauncherTokens.Spacing.page)
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
			.frame(height: LauncherTokens.Spacing.hairline)
			.containerValue(\.settingsRule, true)
	}
}

package struct SettingsPanel<Content: View>: View {
	let title: String

	var tone: SettingsPanelTone = .neutral
	var isExpanded: Binding<Bool>?
	@ViewBuilder package let content: Content

	package init(
		title: String,
		tone: SettingsPanelTone = .neutral,
		isExpanded: Binding<Bool>? = nil,
		@ViewBuilder content: () -> Content
	) {
		self.title = title

		self.tone = tone
		self.isExpanded = isExpanded
		self.content = content()
	}

	@Environment(\.launcherTheme) private var theme
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	package var body: some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
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
									.padding(.horizontal, LauncherTokens.Spacing.content)
							}
							rows[index]
								.frame(maxWidth: .infinity, alignment: .leading)
								.padding(.horizontal, LauncherTokens.Spacing.content)
								.padding(
									.vertical, LauncherTokens.ControlPadding.settingsRowVertical)
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
			.font(LauncherTokens.Typography.sectionLabel)
			.foregroundStyle(tone == .neutral ? theme.textSecondary : tone.color(in: theme))
			.padding(.leading, LauncherTokens.Spacing.content)
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
				.padding(.trailing, LauncherTokens.Spacing.content)
				.padding(.top, LauncherTokens.Spacing.section)
				.contentShape(.rect)
			}
			.buttonStyle(.plain)
			.keyboardFocusIndicator(
				in: RoundedRectangle(cornerRadius: LauncherTokens.Radius.control)
			)
			.accessibilityValue(isExpanded.wrappedValue ? "Expanded" : "Collapsed")
		} else {
			label.padding(.top, LauncherTokens.Spacing.section)
		}
	}
}

package enum SettingsPanelTone {
	case neutral
	case success
	case warning
	case danger

	func color(in theme: LauncherTheme) -> Color {
		return switch self {
		case .neutral: .primary
		case .success: theme.successInk
		case .warning: theme.warningInk
		case .danger: theme.dangerText
		}
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
		SettingsPanel(title: title, tone: .danger) {
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
			HStack(spacing: LauncherTokens.Spacing.control) {
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
			HStack(spacing: LauncherTokens.Spacing.section) {
				// A small ideal width lets a long detail wrap beside the action instead of dropping below.
				label
					.frame(minWidth: 0, idealWidth: 240, maxWidth: .infinity, alignment: .leading)
					.layoutPriority(1)
				actionGroup
			}
			VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
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
		HStack(spacing: LauncherTokens.Spacing.control) {
			actions.fixedSize(horizontal: true, vertical: false)
		}
	}

	@ViewBuilder
	private var label: some View {
		VStack(alignment: .leading, spacing: LauncherTokens.Spacing.compact) {
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
