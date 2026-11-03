// SPDX-License-Identifier: MPL-2.0

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
	@Environment(\.launcherTheme) private var theme
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
	let actions: any LauncherActions
	let restartOnboarding: () -> Void
	let requestLauncherUpdateCheck: () -> Void
	let developerSimulation: DeveloperSimulationBinding?
	let windowSize: CGSize
	@Environment(\.dismiss) private var dismiss
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Binding var selectedSection: SettingsSection
	@State private var presentedDocument: BundledDocument?
	@Namespace private var railSelection

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
				lifecycle: lifecycle,
				installation: installation,
				selectionNamespace: railSelection
			)
			Divider()
				.overlay(theme.hairline)

			ZStack(alignment: .bottomTrailing) {
				Group {
					switch selectedSection {
					case .game:
						GameSettingsPage(
							settings: settings,
							gameSession: gameSession,
							lifecycle: lifecycle
						)
					case .appearance:
						AppearanceSettingsPage(
							settings: settings,
							customization: customization,
							lifecycle: lifecycle,
							presetCatalog: presetCatalog,
							actions: actions
						)
					case .integration:
						IntegrationSettingsPage(
							settings: settings
						)
					case .updates:
						UpdatesSettingsPage(
							settings: settings,
							communication: communication,
							installation: installation,
							lifecycle: lifecycle,
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
							)
						)
					case .statistics:
						PlaytimeStatisticsPage(
							controller: playtimeStatistics,
							regions: settings.regionAccess.selectableRegions.filter {
								installation.isRegionInstalled($0)
							}
						)
					case .help:
						HelpSettingsPage(
							region: installation.region,
							runtimeName: lifecycle.state.readiness.runtimeName,
							actions: actions,
							installation: installation,
							gameSession: gameSession,
							lifecycle: lifecycle,
							restartOnboarding: restartOnboarding
						)
					case .about:
						AboutSettingsPage(
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
									simulation: developerSimulation
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
					FloatingActionBar {
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
						FloatingDoneButton {
							dismiss()
						}
					}
				}
				.padding(.trailing, 24)
				.padding(.top, LauncherTokens.Spacing.control)
				.padding(.bottom, 16)
				.background {
					FloatingActionFooterFade(height: 94)
				}
			}
		}
		.tint(theme.accentFill)
		.background(theme.sheetTint)
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
				accentColor: customization.accentColor
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

private struct SettingsNavigationRail: View {
	@Environment(\.launcherTheme) private var theme
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Binding var selection: SettingsSection
	let isDeveloperMode: Bool
	let lifecycle: LauncherLifecycleStore
	let installation: InstallationController
	let selectionNamespace: Namespace.ID

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			// Group captions title the rail, so it has no caption of its own.
			VStack(spacing: 16) {
				ForEach(SettingsGroup.allCases, id: \.self) { group in
					let sections = visibleSections.filter { $0.group == group }
					if !sections.isEmpty {
						VStack(alignment: .leading, spacing: 2) {
							if let caption = group.caption {
								NavigationRailCaption(text: caption)
									.padding(.horizontal, 8)
							}
							ForEach(sections) { section in
								NavigationRailRow(
									title: section.title,
									systemImage: section.systemImage,
									isSelected: selection == section,
									selectionNamespace: selectionNamespace
								) {
									select(section)
								}
							}
						}
					}
				}
			}
			.padding(.horizontal, 12)
			.padding(.top, 24)

			Spacer()

			SettingsOperationStrip(lifecycle: lifecycle, installation: installation)
				.padding(.horizontal, 16)
				.padding(.bottom, 16)
		}
		.frame(width: LauncherVisuals.Layout.railWidth)
		.background(theme.footerFill)
	}

	/// Moves the selection. The motion grows with the number of rows the indicator crosses.
	private func select(_ section: SettingsSection) {
		let sections = visibleSections
		let previous = sections.firstIndex(of: selection) ?? 0
		let next = sections.firstIndex(of: section) ?? 0
		withLauncherAnimation(.select, reduceMotion: reduceMotion, hops: abs(next - previous)) {
			selection = section
		}
	}

	private var visibleSections: [SettingsSection] {
		#if DEBUG
			SettingsSection.allCases.filter { $0 != .developer || isDeveloperMode }
		#else
			SettingsSection.allCases
		#endif
	}
}
