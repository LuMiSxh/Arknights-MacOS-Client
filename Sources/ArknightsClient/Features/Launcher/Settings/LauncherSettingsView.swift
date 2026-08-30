// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct LauncherSettingsView: View {
	let model: LauncherViewModel
	let restartOnboarding: () -> Void
	let requestLauncherUpdateCheck: () -> Void
	@Environment(\.dismiss) private var dismiss
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var selectedSection = SettingsSection.general
	@State private var presentedDocument: BundledDocument?

	var body: some View {
		HStack(spacing: 0) {
			SettingsNavigationRail(
				selection: $selectedSection,
				isDeveloperMode: model.isDeveloperMode,
				accentColor: model.customization.accentColor
			)
			Divider()
				.overlay(Color.white.opacity(0.08))

			ZStack(alignment: .bottomTrailing) {
				Group {
					switch selectedSection {
					case .general:
						GeneralSettingsPage(
							settings: model.settings,
							customization: model.customization,
							gameSession: model.gameSession,
							lifecycle: model.lifecycle,
							presetCatalog: model.presetCatalog,
							accentColor: model.customization.accentColor,
							resetArtwork: model.resetArtwork,
							restartOnboarding: restartOnboarding
						)
					case .audio:
						AudioSettingsPage(
							settings: model.settings,
							accentColor: model.customization.accentColor
						)
					case .updates:
						UpdatesSettingsPage(
							settings: model.settings,
							communication: model.communication,
							installation: model.installation,
							lifecycle: model.lifecycle,
							accentColor: model.customization.accentColor,
							appVersion: IssueReportURL.appVersion,
							checkLauncherUpdates: requestLauncherUpdateCheck,
							checkGameUpdates: model.checkGameUpdates
						)
					case .installation:
						InstallationSettingsPage(
							settings: model.settings,
							installation: model.installation,
							gameSession: model.gameSession,
							lifecycle: model.lifecycle,
							accentColor: model.customization.accentColor,
							selectRegion: model.selectRegion,
							chooseInstallDirectory: model.chooseInstallDirectory,
							locateExistingInstallation: model.locateExistingInstallation,
							repairGame: model.repairGame,
							resetAllLauncherSettings: model.resetAllLauncherSettings,
							uninstallGame: model.uninstallGame
						)
					case .storage:
						StorageOverviewPage(
							controller: model.storageOverview,
							copy: StorageStrings.copy(),
							actions: StorageOverviewActions(
								clearGameCaches: model.storage.clearGameCache,
								clearGalleryCache: model.storage.clearPresetGalleryCache,
								revealLogs: model.storage.revealLogs
							),
							accentColor: model.customization.accentColor
						)
					case .statistics:
						PlaytimeStatisticsPage(
							controller: model.playtimeStatistics,
							accentColor: model.customization.accentColor
						)
					case .about:
						AboutSettingsPage(
							accentColor: model.customization.accentColor,
							launcherIconManager: model.launcherIconManager,
							branding: model.refreshController.branding,
							revealApplication: model.storage.revealApplication,
							presentedDocument: $presentedDocument
						)
					#if DEBUG
						case .developer:
							DeveloperSettingsPage(
								scenario: developerScenarioBinding,
								accentColor: model.customization.accentColor,
								applyCustomPopup: model.applyDeveloperCustomPopup
							)
					#endif
					}
				}
				.id(selectedSection)
				.transition(.opacity)
				.frame(maxWidth: .infinity, maxHeight: .infinity)

				FloatingActionFooterFade(height: 60)

				FloatingActionBar(tint: model.customization.hudTintColor) {
					if selectedSection == .storage {
						CapsuleActionButton(
							title: L10n.string(StorageStrings.refresh),
							systemImage: "arrow.clockwise",
							tone: .neutral,
							action: model.storageOverview.refresh
						)
						.controlSize(.large)
						.disabled(model.storageOverview.isMeasuring)
					}
					FloatingDoneButton(accentColor: model.customization.accentColor) {
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
		// See ContentView: L10n reads a plain mutex, not an Observable value, so a
		// language change here needs an explicit re-key to redraw immediately.
		.id(model.settings.appLanguage)
		.tint(model.customization.accentColor)
		.background(
			ZStack {
				LauncherVisuals.modalBackground
				model.customization.hudTintColor
			}
		)
		.preferredColorScheme(.dark)
		.animation(
			reduceMotion ? nil : .easeInOut(duration: 0.3),
			value: model.customization.dynamicThemeHue
		)
		.onExitCommand(perform: dismiss.callAsFunction)
		.frame(width: 820, height: 570)
		.sheet(item: $presentedDocument) { document in
			BundledDocumentView(
				document: document,
				accentColor: model.customization.accentColor,
				hudTintColor: model.customization.hudTintColor
			)
		}
	}

	#if DEBUG
		private var developerScenarioBinding: Binding<DeveloperScenario> {
			Binding(
				get: { model.developerScenario ?? .ready },
				set: { model.applyDeveloperScenario($0) }
			)
		}
	#endif
}

private struct SettingsNavigationRail: View {
	@Binding var selection: SettingsSection
	let isDeveloperMode: Bool
	let accentColor: Color

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			Text(SettingsStrings.navigationLabel)
				.font(.caption.monospaced().weight(.semibold))
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
				LauncherVisuals.navigationRailBackground
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
					.accessibilityHidden(true)
				Image(systemName: section.systemImage)
					.frame(width: 17)
					.symbolRenderingMode(.monochrome)
					.accessibilityHidden(true)
				Text(section.title)
					.fontWeight(isSelected ? .semibold : .regular)
				Spacer(minLength: 0)
			}
			.foregroundStyle(isSelected || isHovering ? accentColor : .secondary)
			.padding(.vertical, 9)
			.padding(.trailing, 12)
			.background(backgroundFill, in: .rect(cornerRadius: 8))
			.contentShape(.rect)
			.frame(minHeight: 44)
		}
		.buttonStyle(.plain)
		.keyboardFocusIndicator(
			in: RoundedRectangle(cornerRadius: 8)
		)
		.onHover { isHovering = $0 }
		.accessibilityLabel(section.title)
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
	case storage
	case statistics
	case about
	#if DEBUG
		case developer
	#endif

	var id: String { rawValue }

	var title: String {
		switch self {
		case .general: L10n.string(SettingsStrings.navigationGeneral)
		case .audio: L10n.string(SettingsStrings.navigationAudio)
		case .updates: L10n.string(SettingsStrings.navigationUpdates)
		case .installation: L10n.string(SettingsStrings.navigationInstallation)
		case .storage: L10n.string(SettingsStrings.navigationStorage)
		case .statistics: L10n.string(SettingsStrings.navigationStatistics)
		case .about: L10n.string(SettingsStrings.navigationAbout)
		#if DEBUG
			case .developer: L10n.string(SettingsStrings.navigationDeveloper)
		#endif
		}
	}

	var systemImage: String {
		switch self {
		case .general: "slider.horizontal.3"
		case .audio: "music.note"
		case .updates: "arrow.trianglehead.2.clockwise"
		case .installation: "externaldrive"
		case .storage: "internaldrive"
		case .statistics: "chart.bar.xaxis"
		case .about: "info.circle"
		#if DEBUG
			case .developer: "hammer"
		#endif
		}
	}
}
