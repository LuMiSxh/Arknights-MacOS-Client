// SPDX-License-Identifier: MPL-2.0

import SwiftUI

#if DEBUG
	/// A temporary, debug-only page for comparing the real shared control implementations.
	struct DeveloperComponentLabPage: View {
		let accentColor: Color
		@Environment(\.dismiss) private var dismiss
		@State private var quietToggle = false
		@State private var panelToggle = true
		@State private var compactToggle = false
		@State private var accentIntensity = LabAccentIntensity.standard
		@State private var pickerSelection = LabPickerChoice.primary
		@State private var segmentSelection = LabSegment.compact
		@State private var text = "Shared component input"
		@FocusState private var focusedAction: Bool

		private var labAccent: Color {
			switch accentIntensity {
			case .subtle: accentColor.opacity(0.58)
			case .standard: accentColor.opacity(0.82)
			case .strong: accentColor.opacity(1)
			}
		}

		var body: some View {
			SettingsPage(
				title: "Temporary Component Design Lab",
				subtitle: "Debug-only comparison page for shared launcher components.",
				accentColor: labAccent
			) {
				accentIntensityPanel
				togglePanel
				actionPanel
				inputPanel
				iconPanel
				hudPanel
			}
			.safeAreaInset(edge: .bottom) {
				HStack {
					Spacer()
					CapsuleActionButton(
						title: "Close Lab", tone: .neutral, action: dismiss.callAsFunction)
				}
				.padding(.horizontal, LauncherVisuals.Spacing.page)
				.padding(.vertical, LauncherVisuals.Spacing.control)
			}
			.frame(minWidth: 720, minHeight: 640)
			.preferredColorScheme(.dark)
		}

		private var accentIntensityPanel: some View {
			SettingsPanel(title: "Dynamic accent intensity", systemImage: "circle.lefthalf.filled")
			{
				Text(
					"Selected and focused controls use the artwork-derived accent passed into this page."
				)
				.font(.callout)
				.foregroundStyle(.secondary)
				AdaptiveSegmentedControl(
					selection: $accentIntensity,
					options: LabAccentIntensity.allCases,
					accentColor: labAccent
				) { intensity in
					Text(intensity.title)
				}
			}
		}

		private var togglePanel: some View {
			SettingsPanel(title: "Native toggle treatments", systemImage: "switch.2") {
				SettingsActionRow(
					title: "Shared toggle row",
					detail: "The standard row keeps the native switch and quiet label spacing."
				) {
					SettingsToggle("Shared toggle", isOn: $quietToggle, accentColor: labAccent)
				}
				SettingsHairline()
				SettingsPanel(title: "Quiet nested panel", systemImage: "rectangle.inset.filled") {
					SettingsActionRow(
						title: "Panel toggle",
						detail: "The same native control inside a quiet panel surface."
					) {
						Toggle("Panel toggle", isOn: $panelToggle)
							.labelsHidden()
							.toggleStyle(.switch)
							.tint(labAccent)
					}
				}
				SettingsActionRow(
					title: "Compact native row",
					detail: "A short row keeps the switch aligned without a custom toggle engine."
				) {
					Toggle("Compact toggle", isOn: $compactToggle)
						.labelsHidden()
						.toggleStyle(.switch)
						.controlSize(.small)
						.tint(labAccent)
				}
			}
		}

		private var actionPanel: some View {
			SettingsPanel(title: "Action states", systemImage: "capsule") {
				Text(
					"Enabled and disabled examples use the shared semantic surface and state resolver."
				)
				.font(.callout)
				.foregroundStyle(.secondary)
				statePair(title: "Primary", tone: .accent(labAccent))
				statePair(title: "Secondary", tone: .neutral)
				statePair(title: "Warning", tone: .warning)
				statePair(title: "Danger", tone: .danger)
				SettingsHairline()
				HStack(spacing: LauncherVisuals.Spacing.control) {
					CapsuleActionButton(
						title: "Default action",
						systemImage: "return",
						tone: .accent(labAccent),
						action: {}
					)
					.keyboardShortcut(.defaultAction)
					CapsuleActionButton(
						title: "Focus sample",
						systemImage: "scope",
						tone: .neutral,
						action: { focusedAction = true }
					)
					.focused($focusedAction)
				}
			}
		}

		private func statePair(title: String, tone: CapsuleActionTone) -> some View {
			HStack(spacing: LauncherVisuals.Spacing.control) {
				CapsuleActionButton(
					title: "\(title) enabled",
					systemImage: actionImage(for: tone),
					tone: tone,
					presentation: .compact,
					action: {}
				)
				CapsuleActionButton(
					title: "\(title) disabled",
					systemImage: actionImage(for: tone),
					tone: tone,
					presentation: .compact,
					action: {}
				)
				.disabled(true)
			}
		}

		private func actionImage(for tone: CapsuleActionTone) -> String {
			switch tone {
			case .accent: "checkmark"
			case .neutral: "ellipsis"
			case .warning: "exclamationmark.triangle"
			case .danger: "trash"
			}
		}

		private var inputPanel: some View {
			SettingsPanel(title: "Native input controls", systemImage: "slider.horizontal.3") {
				GlassMenuPicker(
					selection: $pickerSelection,
					options: LabPickerChoice.allCases.map { ($0, $0.title) },
					accentColor: labAccent
				)
				AdaptiveSegmentedControl(
					selection: $segmentSelection,
					options: LabSegment.allCases,
					accentColor: labAccent
				) { segment in
					Text(segment.title)
				}
				ThemedTextField(
					"Component input",
					prompt: "Type to inspect focus",
					text: $text,
					systemImage: "character.cursor.ibeam",
					accentColor: labAccent
				)
			}
		}

		private var iconPanel: some View {
			SettingsPanel(title: "Icon action sizes", systemImage: "gearshape") {
				Text("The larger default touch target keeps Settings gear actions easy to reach.")
					.font(.callout)
					.foregroundStyle(.secondary)
				HStack(spacing: LauncherVisuals.Spacing.panel) {
					gearExample(size: 36)
					gearExample(size: 44)
					gearExample(size: 52)
				}
			}
		}

		private func gearExample(size: CGFloat) -> some View {
			VStack(spacing: LauncherVisuals.Spacing.tight) {
				IconActionButton(
					title: "Settings gear \(Int(size)) point",
					systemImage: "gearshape",
					tone: .neutral,
					size: size,
					action: {}
				)
				Text("\(Int(size)) pt")
					.font(.caption.monospaced())
					.foregroundStyle(.secondary)
			}
		}

		private var hudPanel: some View {
			SettingsPanel(title: "HUD surface geometry", systemImage: "rectangle.roundedtop") {
				Text(
					"The compact and expanded examples share one pill surface and progress outline."
				)
				.font(.callout)
				.foregroundStyle(.secondary)
				HUDPillSurface(progress: 0.68, progressTint: labAccent) {
					HStack {
						Text("Downloading update")
						Spacer()
						Text("68%")
							.fontWeight(.semibold)
					}
					.padding(.horizontal, LauncherVisuals.Control.hudHorizontalPadding)
					.padding(.vertical, LauncherVisuals.Control.hudVerticalPadding)
				}
				HUDPillSurface(isExpanded: true, progressTint: labAccent) {
					VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.tight) {
						Text("Expanded status surface")
							.font(.headline)
						Text("15.21 GB of 22.28 GB · 3.5 MB/s")
							.font(.caption)
							.foregroundStyle(.secondary)
					}
					.padding(LauncherVisuals.Spacing.panel)
				}
			}
		}
	}

	private enum LabAccentIntensity: String, CaseIterable, Hashable {
		case subtle
		case standard
		case strong

		var title: String {
			switch self {
			case .subtle: "Subtle"
			case .standard: "Standard"
			case .strong: "Strong"
			}
		}
	}

	private enum LabPickerChoice: String, CaseIterable, Hashable {
		case primary
		case secondary
		case danger

		var title: String {
			switch self {
			case .primary: "Primary"
			case .secondary: "Secondary"
			case .danger: "Danger"
			}
		}
	}

	private enum LabSegment: String, CaseIterable, Hashable {
		case compact
		case balanced
		case spacious

		var title: String {
			switch self {
			case .compact: "Compact"
			case .balanced: "Balanced"
			case .spacious: "Spacious"
			}
		}
	}
#endif
