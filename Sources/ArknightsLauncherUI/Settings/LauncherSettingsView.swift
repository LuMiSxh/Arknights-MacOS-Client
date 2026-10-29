// SPDX-License-Identifier: MPL-2.0

import ArknightsAudio
import ArknightsCore
import ArknightsCustomization
import ArknightsGameInstallation
import ArknightsGameRuntime
import SwiftUI

#if DEBUG
	typealias DeveloperSimulationBinding = Binding<DeveloperSimulationState>
#else
	typealias DeveloperSimulationBinding = Never
#endif

struct LauncherSettingsView: View {
	package let settings: LauncherPreferencesController
	let customization: CustomizationController
	package let communication: LauncherCommunicationController
	package let installation: InstallationController
	let gameSession: GameSessionController
	package let lifecycle: LauncherLifecycleStore
	let storage: StorageMaintenanceController
	let storageOverview: StorageOverviewController
	let playtimeStatistics: PlaytimeStatisticsController
	let presetCatalog: PresetCatalogService
	package let launcherIconManager: LauncherIconManager
	let branding: LauncherBranding?
	let actions: any LauncherActions
	let restartOnboarding: () -> Void
	let requestLauncherUpdateCheck: () -> Void
	let developerSimulation: DeveloperSimulationBinding?
	let windowSize: CGSize
	@Environment(\.dismiss) private var dismiss
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Binding var selectedSection: SettingsSection
	@State private var presentedDocument: BundledDocument?

	private var sheetSize: CGSize {
		let margin = AppConstants.Settings.windowMargin * 2
		return CGSize(
			width: min(
				max(windowSize.width - margin, AppConstants.Settings.minWidth),
				AppConstants.Settings.maxWidth),
			height: min(
				max(windowSize.height - margin, AppConstants.Settings.minHeight),
				AppConstants.Settings.maxHeight))
	}

	var body: some View {
		HStack(spacing: 0) {
			SettingsNavigationRail(
				selection: $selectedSection,
				isDeveloperMode: isDeveloperMode,
				accentColor: customization.accentColor,
				lifecycle: lifecycle,
				installation: installation
			)
			Divider()
				.overlay(LauncherVisuals.hairline)

			ZStack(alignment: .bottomTrailing) {
				Group {
					switch selectedSection {
					case .game:
						GameSettingsPage(
							settings: settings,
							gameSession: gameSession,
							lifecycle: lifecycle,
							accentColor: customization.accentColor
						)
					case .appearance:
						AppearanceSettingsPage(
							settings: settings,
							customization: customization,
							lifecycle: lifecycle,
							presetCatalog: presetCatalog,
							accentColor: customization.accentColor,
							actions: actions
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
							actions: actions,
							checkLauncherUpdates: requestLauncherUpdateCheck
						)
					case .servers:
						InstallationSettingsPage(
							settings: settings,
							installation: installation,
							gameSession: gameSession,
							lifecycle: lifecycle,
							accentColor: customization.accentColor,
							actions: actions
						)
					case .storage:
						StorageOverviewPage(
							controller: storageOverview,
							copy: .english,
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
							regions: settings.regionAccess.selectableRegions.filter {
								installation.isRegionInstalled($0)
							},
							accentColor: customization.accentColor
						)
					case .help:
						HelpSettingsPage(
							region: installation.region,
							runtimeName: lifecycle.state.readiness.runtimeName,
							accentColor: customization.accentColor,
							actions: actions,
							installation: installation,
							gameSession: gameSession,
							lifecycle: lifecycle,
							restartOnboarding: restartOnboarding
						)
					case .about:
						AboutSettingsPage(
							accentColor: customization.accentColor,
							launcherIconManager: launcherIconManager,
							branding: branding,
							runtime: gameSession.installedRuntime,
							revealApplication: storage.revealApplication,
							presentedDocument: $presentedDocument
						)
					#if DEBUG
						case .developer:
							if let developerSimulation {
								DeveloperSettingsPage(
									simulation: developerSimulation,
									accentColor: customization.accentColor
								)
							}
					#endif
					}
				}
				.id(selectedSection)
				.environment(\.simulatesMissingXcode, simulatesMissingXcode)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.safeAreaInset(edge: .bottom, spacing: 0) {
				HStack {
					Spacer(minLength: 0)
					FloatingActionBar(tint: customization.hudTintColor) {
						if selectedSection == .storage {
							CapsuleActionButton(
								title: "Refresh",
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
				}
				.padding(.trailing, 26)
				.padding(.top, LauncherVisuals.Spacing.control)
				.padding(.bottom, 18)
				.background {
					FloatingActionFooterFade(height: 94)
				}
			}
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
			LauncherMotion.animation(.crossfade, reduceMotion: reduceMotion),
			value: customization.dynamicThemeHue
		)
		.onExitCommand(perform: dismiss.callAsFunction)
		.frame(width: sheetSize.width, height: sheetSize.height)
		.presentationSizing(.fitted)
		.sheet(item: $presentedDocument) { document in
			BundledDocumentView(
				document: document,
				accentColor: customization.accentColor,
				hudTintColor: customization.hudTintColor
			)
		}
	}

	private var simulatesMissingXcode: Bool {
		#if DEBUG
			developerSimulation?.wrappedValue.xcodeMissing ?? false
		#else
			false
		#endif
	}

	private var isDeveloperMode: Bool {
		#if DEBUG
			developerSimulation != nil
		#else
			false
		#endif
	}
}

private struct SettingsRailCaption: View {
	let text: String

	var body: some View {
		Text(text)
			.font(.caption.monospaced().weight(.semibold))
			.tracking(1.4)
			.foregroundStyle(.tertiary)
	}
}

private struct SettingsNavigationRail: View {
	@Binding var selection: SettingsSection
	let isDeveloperMode: Bool
	package let accentColor: Color
	package let lifecycle: LauncherLifecycleStore
	package let installation: InstallationController

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			// Group captions title the rail, so it has no caption of its own.
			VStack(spacing: 18) {
				ForEach(SettingsGroup.allCases, id: \.self) { group in
					let sections = visibleSections.filter { $0.group == group }
					if !sections.isEmpty {
						VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.compact) {
							if let caption = group.caption {
								SettingsRailCaption(text: caption)
									.padding(.horizontal, 8)
							}
							ForEach(sections) { section in
								SettingsNavigationButton(
									section: section,
									isSelected: selection == section,
									accentColor: accentColor
								) {
									selection = section
								}
							}
						}
					}
				}
			}
			.padding(.horizontal, 10)
			.padding(.top, 22)

			Spacer()

			SettingsOperationStrip(lifecycle: lifecycle, installation: installation)
				.padding(.horizontal, 18)
				.padding(.bottom, 18)
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
	package let accentColor: Color
	let action: () -> Void
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
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
			.animation(
				LauncherMotion.animation(.hover, reduceMotion: reduceMotion), value: isHovering)
		}
		.buttonStyle(ActionPressStyle(intensity: .pressOnly))
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
