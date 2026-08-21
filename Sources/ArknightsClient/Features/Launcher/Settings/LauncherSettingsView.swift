// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct LauncherSettingsView: View {
	var model: LauncherViewModel
	let restartOnboarding: () -> Void
	@Environment(\.dismiss) private var dismiss
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var selectedSection = SettingsSection.general
	@State private var presentedDocument: BundledDocument?

	var body: some View {
		HStack(spacing: 0) {
			SettingsNavigationRail(
				selection: $selectedSection,
				isDeveloperMode: model.isDeveloperMode,
				accentColor: model.accentColor
			)
			Divider()
				.overlay(Color.white.opacity(0.08))

			ZStack(alignment: .bottomTrailing) {
				Group {
					switch selectedSection {
					case .general:
						GeneralSettingsPage(
							model: model,
							restartOnboarding: restartOnboarding
						)
					case .audio:
						AudioSettingsPage(model: model)
					case .updates:
						UpdatesSettingsPage(model: model)
					case .installation:
						InstallationSettingsPage(model: model)
					case .about:
						AboutSettingsPage(model: model, presentedDocument: $presentedDocument)
					#if DEBUG
						case .developer:
							DeveloperSettingsPage(model: model)
					#endif
					}
				}
				.id(selectedSection)
				.transition(.opacity)
				.frame(maxWidth: .infinity, maxHeight: .infinity)

				LinearGradient(
					colors: [.clear, Color.black.opacity(0.45)],
					startPoint: .top,
					endPoint: .bottom
				)
				.frame(height: 60)
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
				.allowsHitTesting(false)

				FloatingActionBar(tint: model.hudTintColor) {
					FloatingDoneButton(accentColor: model.accentColor) {
						dismiss()
					}
				}
				.padding(.trailing, 26)
				.padding(.bottom, 18)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.animation(
				reduceMotion ? nil : .easeInOut(duration: 0.18),
				value: selectedSection
			)
		}
		.tint(model.accentColor)
		.background(
			ZStack {
				Color(red: 0.07, green: 0.07, blue: 0.08)
				model.hudTintColor
			}
		)
		.preferredColorScheme(.dark)
		.animation(
			reduceMotion ? nil : .easeInOut(duration: 0.3),
			value: model.dynamicThemeHue
		)
		.frame(width: 820, height: 570)
		.sheet(item: $presentedDocument) { document in
			BundledDocumentView(
				document: document,
				accentColor: model.accentColor,
				hudTintColor: model.hudTintColor
			)
		}
	}
}

private struct SettingsNavigationRail: View {
	@Binding var selection: SettingsSection
	let isDeveloperMode: Bool
	let accentColor: Color

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
						isSelected: selection == section,
						accentColor: accentColor
					) {
						selection = section
					}
				}
			}
			.padding(.horizontal, 10)

			Spacer()

			HStack(spacing: 8) {
				Rectangle()
					.fill(accentColor)
					.frame(width: 28, height: 2)
				Rectangle()
					.fill(LauncherVisuals.hairline)
					.frame(height: 1)
			}
			.padding(18)
		}
		.frame(width: 178)
		.background(
			ZStack {
				Color.black.opacity(0.28)
				accentColor.opacity(0.03)
			}
		)
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
	let accentColor: Color
	let action: () -> Void
	@State private var isHovering = false

	var body: some View {
		Button(action: action) {
			HStack(spacing: 10) {
				RoundedRectangle(cornerRadius: 1)
					.fill(isSelected ? accentColor : .clear)
					.frame(width: 2, height: 20)
				Image(systemName: section.systemImage)
					.frame(width: 17)
					.symbolRenderingMode(.monochrome)
				Text(section.title)
					.fontWeight(isSelected ? .semibold : .regular)
				Spacer(minLength: 0)
			}
			.foregroundStyle(isSelected || isHovering ? accentColor : .secondary)
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
		if isSelected { return accentColor.opacity(0.12) }
		if isHovering { return accentColor.opacity(0.06) }
		return .clear
	}
}

private enum SettingsSection: String, CaseIterable, Identifiable {
	case general
	case audio
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
		case .audio: "Audio"
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
		case .audio: "music.note"
		case .updates: "arrow.trianglehead.2.clockwise"
		case .installation: "externaldrive"
		case .about: "info.circle"
		#if DEBUG
			case .developer: "hammer"
		#endif
		}
	}
}
