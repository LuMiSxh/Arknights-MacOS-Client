// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct SettingsPage<Content: View>: View {
	let title: String
	let subtitle: String
	let accentColor: Color
	@ViewBuilder let content: Content

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 18) {
				VStack(alignment: .leading, spacing: 7) {
					Text(title)
						.font(.largeTitle.bold())
					Text(subtitle)
						.foregroundStyle(.secondary)
					HStack(spacing: 8) {
						Rectangle().fill(accentColor).frame(width: 72, height: 3)
						Rectangle().fill(.secondary.opacity(0.28))
							.frame(height: 1)
							.frame(maxWidth: .infinity)
					}
					.padding(.top, 5)
				}
				content
			}
			.padding(.horizontal, 26)
			.padding(.top, 26)
			.padding(.bottom, 72)
		}
		.contentMargins(.top, 26, for: .scrollIndicators)
		.contentMargins(.bottom, 22, for: .scrollIndicators)
		.scrollIndicators(.automatic)
	}
}

/// A subtle row separator matching the nav rail's hairline, used instead of the stock
/// `Divider()` inside glass panels so rows read as one soft surface, not a bordered form.
struct SettingsHairline: View {
	var body: some View {
		Rectangle()
			.fill(SettingsVisuals.hairline)
			.frame(height: 1)
	}
}

struct SettingsPanel<Content: View>: View {
	let title: String
	let systemImage: String
	@ViewBuilder let content: Content

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			Label(title, systemImage: systemImage)
				.font(.headline)
				.symbolRenderingMode(.hierarchical)
			content
		}
		.padding(18)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color.white.opacity(0.04), in: .rect(cornerRadius: 18))
		.overlay {
			RoundedRectangle(cornerRadius: 18)
				.strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
		}
	}
}

/// Same shape as `SettingsPanel`, tinted red for actions that are destructive or
/// depend on undocumented system behavior (see the panel's own contents for which).
struct DangerZonePanel<Content: View>: View {
	@ViewBuilder let content: Content

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			Label("Danger Zone", systemImage: "exclamationmark.triangle.fill")
				.font(.headline)
				.foregroundStyle(SettingsVisuals.danger)
			content
		}
		.padding(18)
		.frame(maxWidth: .infinity, alignment: .leading)
		.adaptiveGlassEffect(in: .rect(cornerRadius: 18))
		.overlay {
			RoundedRectangle(cornerRadius: 18)
				.strokeBorder(SettingsVisuals.danger.opacity(0.45), lineWidth: 1)
		}
	}
}

struct UpdateSettingsRow: View {
	let title: String
	let status: String
	@Binding var isEnabled: Bool
	let isChecking: Bool
	let accentColor: Color
	let check: () -> Void

	var body: some View {
		HStack(spacing: 16) {
			VStack(alignment: .leading, spacing: 3) {
				Text(title)
				Text(status)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			Spacer()
			Toggle(title, isOn: $isEnabled)
				.labelsHidden()
				.toggleStyle(.switch)
				.tint(accentColor)
			Button("Check Now", action: check)
				.disabled(isChecking)
		}
	}
}

struct SettingsActionRow<Actions: View>: View {
	let title: String
	let detail: String
	@ViewBuilder let actions: Actions

	var body: some View {
		HStack(spacing: 18) {
			VStack(alignment: .leading, spacing: 3) {
				Text(title)
				Text(detail)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.layoutPriority(1)
			actions
				.fixedSize(horizontal: true, vertical: false)
		}
	}
}

/// A cyan glass chip that stands in for `Picker`'s stock menu-button chrome, so option
/// pickers read as the same interaction language as the landing page's region switcher
/// rather than a default AppKit control.
struct GlassMenuPicker<Value: Hashable>: View {
	let selection: Binding<Value>
	let options: [(value: Value, title: String)]
	let accentColor: Color
	var isDisabled = false

	var body: some View {
		Menu {
			ForEach(options, id: \.value) { option in
				Button {
					selection.wrappedValue = option.value
				} label: {
					if option.value == selection.wrappedValue {
						Label(option.title, systemImage: "checkmark")
					} else {
						Text(option.title)
					}
				}
			}
		} label: {
			HStack(spacing: 5) {
				Text(currentTitle)
				Image(systemName: "chevron.up.chevron.down")
					.font(.system(size: 9, weight: .bold))
					.accessibilityHidden(true)
			}
			.font(.system(size: 12, weight: .semibold))
			.foregroundStyle(isDisabled ? AnyShapeStyle(.secondary) : AnyShapeStyle(accentColor))
			.padding(.horizontal, 10)
			.padding(.vertical, 5)
			.background(
				isDisabled ? Color.white.opacity(0.08) : accentColor.opacity(0.15), in: Capsule()
			)
		}
		.menuStyle(.button)
		.buttonStyle(.plain)
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
	@ViewBuilder let content: Content

	var body: some View {
		Menu {
			content
		} label: {
			HStack(spacing: 5) {
				Image(systemName: systemImage)
					.accessibilityHidden(true)
				Text(title)
				Image(systemName: "chevron.up.chevron.down")
					.font(.system(size: 9, weight: .bold))
					.accessibilityHidden(true)
			}
			.font(.system(size: 12, weight: .semibold))
			.foregroundStyle(accentColor)
			.padding(.horizontal, 10)
			.padding(.vertical, 5)
			.background(accentColor.opacity(0.15), in: Capsule())
		}
		.menuStyle(.button)
		.buttonStyle(.plain)
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
			}
			.foregroundStyle(isHovering ? accentColor : .primary)
			.padding(.vertical, 4)
			.padding(.horizontal, 6)
			.background(
				isHovering ? accentColor.opacity(0.08) : .clear,
				in: .rect(cornerRadius: 8)
			)
			.contentShape(.rect)
		}
		.buttonStyle(.plain)
		.onHover { isHovering = $0 }
	}
}
