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
			.contentMargins(.top, LauncherVisuals.Spacing.page, for: .scrollIndicators)
			.contentMargins(.bottom, 22, for: .scrollIndicators)
			.scrollIndicators(.automatic)
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

/// A subtle row separator matching the nav rail's hairline, used instead of the stock
/// `Divider()` inside glass panels so rows read as one soft surface, not a bordered form.
package struct SettingsHairline: View {
	package init() {}
	package var body: some View {
		Rectangle()
			.fill(LauncherVisuals.hairline)
			.frame(height: LauncherVisuals.Spacing.hairline)
	}
}

package struct SettingsPanel<Content: View>: View {
	let title: String
	let systemImage: String
	var tone: SettingsPanelTone = .neutral
	/// Makes the header a disclosure button that shows or hides the content.
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
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
	@Environment(\.accessibilityShowBorders) private var showBorders
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	package var body: some View {
		VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.content) {
			header
			if isExpanded?.wrappedValue ?? true {
				content
			}
		}
		.padding(LauncherVisuals.Spacing.panel)
		.frame(maxWidth: .infinity, alignment: .leading)
		.adaptiveGlassEffect(
			tint: nil,
			borderTint: tone.color(for: contrast),
			in: .rect(cornerRadius: LauncherVisuals.Radius.panel),
			showsBorder: false
		)
		.overlay {
			if ownsPanelEdge {
				RoundedRectangle(cornerRadius: LauncherVisuals.Radius.panel)
					.strokeBorder(
						tone.border(for: contrast), lineWidth: LauncherVisuals.Control.borderWidth
					)
					.allowsHitTesting(false)
			}
		}
	}

	private var ownsPanelEdge: Bool {
		AdaptiveGlassSurfaceTreatment.ownsExternalBorder(
			reduceTransparency: reduceTransparency,
			showBorders: showBorders
		)
	}

	@ViewBuilder
	private var header: some View {
		let label = Label(title, systemImage: systemImage)
			.font(.headline)
			.foregroundStyle(tone.color(for: contrast))
			.symbolRenderingMode(.hierarchical)
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
						.font(.caption.weight(.semibold))
						.foregroundStyle(.secondary)
						.rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
						.accessibilityHidden(true)
				}
				.contentShape(.rect)
			}
			.buttonStyle(.plain)
			.keyboardFocusIndicator(in: RoundedRectangle(cornerRadius: LauncherVisuals.Radius.row))
			.accessibilityValue(isExpanded.wrappedValue ? "Expanded" : "Collapsed")
		} else {
			label
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

	func border(for contrast: ColorSchemeContrast) -> Color {
		let opacity =
			contrast == .increased
			? LauncherVisuals.Control.semanticBorderHighContrastOpacity
			: LauncherVisuals.Control.semanticBorderOpacity
		return switch self {
		case .neutral: LauncherVisuals.panelBorder
		case .success: LauncherVisuals.success.opacity(opacity)
		case .warning: LauncherVisuals.warning.opacity(opacity)
		case .danger: LauncherVisuals.dangerForeground.opacity(opacity)
		}
	}
}

/// Same quiet panel geometry as `SettingsPanel`, reserved for destructive actions.
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
	package let accentColor: Color
	package let check: () -> Void

	package init(
		title: String,
		status: String,
		isEnabled: Binding<Bool>,
		isChecking: Bool,
		isDisabled: Bool = false,
		accentColor: Color,
		check: @escaping () -> Void
	) {
		self.title = title
		self.status = status
		self._isEnabled = isEnabled
		self.isChecking = isChecking
		self.isDisabled = isDisabled
		self.accentColor = accentColor
		self.check = check
	}

	package var body: some View {
		SettingsActionRow(title: title, detail: status) {
			HStack(spacing: LauncherVisuals.Spacing.control) {
				SettingsToggle(title, isOn: $isEnabled, accentColor: accentColor)
					.disabled(isDisabled)
				CapsuleActionButton(
					title: "Check Now",
					tone: .accent(accentColor),
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
	/// Technical background shown as a tooltip over the title and detail.
	var help: String?
	@ViewBuilder package let actions: Actions

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
				label
					.frame(maxWidth: .infinity, alignment: .leading)
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
			if let detail {
				Text(detail)
					.font(.caption)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.help(help.map { Text($0) } ?? Text(verbatim: ""))
	}
}
