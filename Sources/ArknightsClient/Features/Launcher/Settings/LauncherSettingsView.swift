// SPDX-License-Identifier: MPL-2.0

import SwiftUI

#if DEBUG
	typealias DeveloperSimulationBinding = Binding<DeveloperSimulationState>
#else
	typealias DeveloperSimulationBinding = Never
#endif

struct LauncherSettingsView: View {
	let settings: LauncherPreferencesController
	let customization: CustomizationController
	let communication: LauncherCommunicationController
	let installation: InstallationController
	let gameSession: GameSessionController
	let lifecycle: LauncherLifecycleStore
	let storage: StorageMaintenanceController
	let storageOverview: StorageOverviewController
	let playtimeStatistics: PlaytimeStatisticsController
	let presetCatalog: PresetCatalogService
	let launcherIconManager: LauncherIconManager
	let branding: LauncherBranding?
	let resetArtwork: () -> Void
	let checkGameUpdates: () -> Void
	let selectRegion: (GameRegion) -> Void
	let chooseInstallDirectory: () -> Void
	let locateExistingInstallation: () -> Void
	let repairGame: () -> Void
	let resetAllLauncherSettings: () -> Void
	let uninstallGame: () -> Void
	let restartOnboarding: () -> Void
	let requestLauncherUpdateCheck: () -> Void
	let developerSimulation: DeveloperSimulationBinding?
	let applyCustomPopup: ((String, String) -> Void)?
	@Environment(\.dismiss) private var dismiss
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var selectedSection = SettingsSection.general
	@State private var presentedDocument: BundledDocument?

	var body: some View {
		HStack(spacing: 0) {
			SettingsNavigationRail(
				selection: $selectedSection,
				isDeveloperMode: isDeveloperMode,
				accentColor: customization.accentColor
			)
			Divider()
				.overlay(LauncherVisuals.hairline)

			ZStack(alignment: .bottomTrailing) {
				Group {
					switch selectedSection {
					case .general:
						GeneralSettingsPage(
							settings: settings,
							customization: customization,
							gameSession: gameSession,
							lifecycle: lifecycle,
							presetCatalog: presetCatalog,
							accentColor: customization.accentColor,
							resetArtwork: resetArtwork,
							restartOnboarding: restartOnboarding
						)
					case .audio:
						AudioSettingsPage(
							settings: settings,
							accentColor: customization.accentColor
						)
					case .updates:
						UpdatesSettingsPage(
							settings: settings,
							communication: communication,
							installation: installation,
							lifecycle: lifecycle,
							accentColor: customization.accentColor,
							appVersion: IssueReportURL.appVersion,
							checkLauncherUpdates: requestLauncherUpdateCheck,
							checkGameUpdates: checkGameUpdates
						)
					case .installation:
						InstallationSettingsPage(
							settings: settings,
							installation: installation,
							gameSession: gameSession,
							lifecycle: lifecycle,
							accentColor: customization.accentColor,
							selectRegion: selectRegion,
							chooseInstallDirectory: chooseInstallDirectory,
							locateExistingInstallation: locateExistingInstallation,
							repairGame: repairGame,
							resetAllLauncherSettings: resetAllLauncherSettings,
							uninstallGame: uninstallGame
						)
					case .storage:
						StorageOverviewPage(
							controller: storageOverview,
							copy: StorageStrings.copy(),
							actions: StorageOverviewActions(
								clearGameCaches: storage.clearGameCache,
								clearGalleryCache: storage.clearPresetGalleryCache,
								revealLogs: storage.revealLogs
							),
							accentColor: customization.accentColor
						)
					case .statistics:
						PlaytimeStatisticsPage(
							controller: playtimeStatistics,
							regions: GameRegion.selectableCases(
								canaryEnabled: settings.canaryFeaturesEnabled,
								chinaClientsEnabled: settings.chinaClientsEnabled,
								taiwanClientEnabled: settings.taiwanClientEnabled
							),
							accentColor: customization.accentColor
						)
					case .about:
						AboutSettingsPage(
							region: installation.region,
							accentColor: customization.accentColor,
							launcherIconManager: launcherIconManager,
							branding: branding,
							revealApplication: storage.revealApplication,
							presentedDocument: $presentedDocument
						)
					#if DEBUG
						case .developer:
							if let developerSimulation, let applyCustomPopup {
								DeveloperSettingsPage(
									simulation: developerSimulation,
									accentColor: customization.accentColor,
									applyCustomPopup: applyCustomPopup
								)
							}
					#endif
					}
				}
				.id(selectedSection)
				.frame(maxWidth: .infinity, maxHeight: .infinity)

				FloatingActionFooterFade(height: 60)

				FloatingActionBar(tint: customization.hudTintColor) {
					if selectedSection == .storage {
						CapsuleActionButton(
							title: StorageStrings.refresh,
							systemImage: "arrow.clockwise",
							tone: .neutral,
							action: storageOverview.refreshNow
						)
						.controlSize(.large)
						.disabled(storageOverview.isMeasuring)
					}
					FloatingDoneButton(accentColor: customization.accentColor) {
						dismiss()
					}
				}
				.padding(.trailing, 26)
				.padding(.bottom, 18)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.tint(customization.accentColor)
		.background(
			ZStack {
				LauncherVisuals.modalBackground
				customization.hudTintColor
			}
		)
		.preferredColorScheme(.dark)
		.animation(
			reduceMotion ? nil : .easeInOut(duration: 0.3),
			value: customization.dynamicThemeHue
		)
		.onExitCommand(perform: dismiss.callAsFunction)
		.frame(width: 820, height: 570)
		.sheet(item: $presentedDocument) { document in
			BundledDocumentView(
				document: document,
				accentColor: customization.accentColor,
				hudTintColor: customization.hudTintColor
			)
		}
	}

	private var isDeveloperMode: Bool {
		#if DEBUG
			developerSimulation != nil
		#else
			false
		#endif
	}
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

			VStack(spacing: LauncherVisuals.Spacing.compact) {
				ForEach(visibleSections) { section in
					SettingsNavigationButton(
						section: section,
						isSelected: selection == section,
						accentColor: accentColor,
					) {
						selection = section
					}
				}
			}
			.padding(.horizontal, 10)

			Spacer()

			HStack(spacing: LauncherVisuals.Spacing.control) {
				Rectangle()
					.fill(LauncherVisuals.selectedNavigationMarker(for: accentColor))
					.frame(width: 28, height: 2)
				Rectangle()
					.fill(LauncherVisuals.hairline)
					.frame(height: 1)
			}
			.padding(18)
		}
		.frame(width: 164)
		.background(LauncherVisuals.navigationRailBackground)
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
			HStack(spacing: LauncherVisuals.Spacing.control) {
				RoundedRectangle(cornerRadius: 1)
					.fill(isSelected ? accentColor : .clear)
					.frame(width: 2, height: 18)
					.accessibilityHidden(true)
				Image(systemName: section.systemImage)
					.frame(width: 17)
					.symbolRenderingMode(.monochrome)
					.accessibilityHidden(true)
				Text(section.title)
					.fontWeight(isSelected ? .semibold : .regular)
				Spacer(minLength: 0)
			}
			.foregroundStyle(isSelected ? accentColor : (isHovering ? .primary : .secondary))
			.padding(.vertical, 8)
			.padding(.trailing, 12)
			.background(backgroundFill, in: .rect(cornerRadius: LauncherVisuals.Radius.row))
			.contentShape(.rect)
			.frame(minHeight: 38)
		}
		.buttonStyle(.plain)
		.keyboardFocusIndicator(
			in: RoundedRectangle(cornerRadius: LauncherVisuals.Radius.row)
		)
		.onHover { isHovering = $0 }
		.accessibilityLabel(section.title)
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}

	private var backgroundFill: Color {
		if isSelected { return LauncherVisuals.selectedNavigationFill(for: accentColor) }
		if isHovering { return LauncherVisuals.navigationHoverFill }
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
		case .general: SettingsStrings.navigationGeneral
		case .audio: SettingsStrings.navigationAudio
		case .updates: SettingsStrings.navigationUpdates
		case .installation: SettingsStrings.navigationInstallation
		case .storage: SettingsStrings.navigationStorage
		case .statistics: SettingsStrings.navigationStatistics
		case .about: SettingsStrings.navigationAbout
		#if DEBUG
			case .developer: SettingsStrings.navigationDeveloper
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
