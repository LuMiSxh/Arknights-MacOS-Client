// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct LauncherSettingsView: View {
	@ObservedObject var model: LauncherViewModel
	@Environment(\.dismiss) private var dismiss
	@State private var selectedSection = SettingsSection.general
	@State private var confirmsGameUninstall = false
	@State private var confirmsForceMigration = false
	@State private var presentedDocument: BundledDocument?

	var body: some View {
		HStack(spacing: 0) {
			SettingsNavigationRail(
				selection: $selectedSection,
				isDeveloperMode: model.isDeveloperMode
			)
			Divider()
			Group {
				switch selectedSection {
				case .general:
					GeneralSettingsPage(model: model)
				case .updates:
					UpdatesSettingsPage(model: model)
				case .installation:
					InstallationSettingsPage(
						model: model,
						confirmsGameUninstall: $confirmsGameUninstall,
						confirmsForceMigration: $confirmsForceMigration
					)
				case .about:
					AboutSettingsPage(model: model, presentedDocument: $presentedDocument)
				#if DEBUG
					case .developer:
						DeveloperSettingsPage(model: model)
				#endif
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.background(.ultraThinMaterial)
		}
		.tint(SettingsVisuals.cyan)
		.background(.thinMaterial)
		.frame(width: 820, height: 570)
		.toolbar {
			ToolbarItem(placement: .confirmationAction) {
				Button("Done") { dismiss() }
					.buttonStyle(.glassProminent)
					.tint(SettingsVisuals.cyan)
			}
		}
		.confirmationDialog(
			"Uninstall Arknights?",
			isPresented: $confirmsGameUninstall,
			titleVisibility: .visible
		) {
			Button("Move Game to Trash", role: .destructive, action: model.uninstallGame)
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("The launcher stays installed.")
		}
		.confirmationDialog(
			"Force Wine Setup to Run Again?",
			isPresented: $confirmsForceMigration,
			titleVisibility: .visible
		) {
			Button("Force Migration", role: .destructive, action: model.forcePrefixMigration)
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("Game files and saves stay untouched; only the next launch takes longer.")
		}
		.sheet(item: $presentedDocument) { document in
			BundledDocumentView(document: document)
		}
	}
}

enum SettingsVisuals {
	static let cyan = Color(red: 0.094, green: 0.82, blue: 1)
	static let controlTint = Color(red: 0.72, green: 0.74, blue: 0.77)
	static let navigationSelection = cyan.opacity(0.12)
	static let hairline = Color.white.opacity(0.12)
}

private struct SettingsNavigationRail: View {
	@Binding var selection: SettingsSection
	let isDeveloperMode: Bool

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			Text("SETTINGS")
				.font(.caption2.monospaced().weight(.semibold))
				.tracking(1.4)
				.foregroundStyle(.tertiary)
				.padding(.horizontal, 18)
				.padding(.top, 22)
				.padding(.bottom, 14)

			VStack(spacing: 5) {
				ForEach(visibleSections) { section in
					SettingsNavigationButton(
						section: section,
						isSelected: selection == section
					) {
						selection = section
					}
				}
			}
			.padding(.horizontal, 10)

			Spacer()

			HStack(spacing: 8) {
				Rectangle()
					.fill(SettingsVisuals.cyan)
					.frame(width: 28, height: 2)
				Rectangle()
					.fill(SettingsVisuals.hairline)
					.frame(height: 1)
			}
			.padding(18)
		}
		.frame(width: 178)
		.background(.regularMaterial)
	}

	private var visibleSections: [SettingsSection] {
		#if DEBUG
			SettingsSection.allCases.filter { $0 != .developer || isDeveloperMode }
		#else
			SettingsSection.allCases
		#endif
	}
}

private struct SettingsNavigationButton: View {
	let section: SettingsSection
	let isSelected: Bool
	let action: () -> Void
	@State private var isHovering = false

	var body: some View {
		Button(action: action) {
			HStack(spacing: 10) {
				RoundedRectangle(cornerRadius: 1)
					.fill(isSelected ? SettingsVisuals.cyan : .clear)
					.frame(width: 2, height: 20)
				Image(systemName: section.systemImage)
					.frame(width: 17)
					.symbolRenderingMode(.monochrome)
				Text(section.title)
					.fontWeight(isSelected ? .semibold : .regular)
				Spacer(minLength: 0)
			}
			.foregroundStyle(isSelected || isHovering ? SettingsVisuals.cyan : .secondary)
			.padding(.vertical, 9)
			.padding(.trailing, 12)
			.background(backgroundFill, in: .rect(cornerRadius: 8))
			.contentShape(.rect)
		}
		.buttonStyle(.plain)
		.onHover { isHovering = $0 }
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}

	private var backgroundFill: Color {
		if isSelected { return SettingsVisuals.navigationSelection }
		if isHovering { return SettingsVisuals.cyan.opacity(0.06) }
		return .clear
	}
}

private enum SettingsSection: String, CaseIterable, Identifiable {
	case general
	case updates
	case installation
	case about
	#if DEBUG
		case developer
	#endif

	var id: String { rawValue }

	var title: String {
		switch self {
		case .general: "General"
		case .updates: "Updates"
		case .installation: "Installation"
		case .about: "About"
		#if DEBUG
			case .developer: "Developer"
		#endif
		}
	}

	var systemImage: String {
		switch self {
		case .general: "slider.horizontal.3"
		case .updates: "arrow.trianglehead.2.clockwise"
		case .installation: "externaldrive"
		case .about: "info.circle"
		#if DEBUG
			case .developer: "hammer"
		#endif
		}
	}
}
