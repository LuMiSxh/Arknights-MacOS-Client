// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsGameRuntime
import SwiftUI

struct InstallationSettingsPage: View {
	@Environment(\.launcherTheme) var theme
	private static let canaryFeaturesTitle = "Canary Features"
	@Bindable var settings: LauncherPreferencesController
	let installation: InstallationController
	let gameSession: GameSessionController
	let lifecycle: LauncherLifecycleStore
	let actions: any LauncherInstallationActions
	let maintenance: any LauncherSettingsActions
	@State private var confirmation: InstallationConfirmation?

	var body: some View {
		SettingsPage(
			title: "Installation",
			subtitle: "Choose a server and manage its game files"
		) {
			SettingsPanel(title: "Server") {
				SettingsActionRow(
					title: "Server",
					detail: "Each server keeps its own game files and updates."
				) {
					GlassMenuPicker(
						selection: regionBinding,
						options: settings.regionAccess.selectableRegions.map {
							($0, $0.displayName)
						},
						isDisabled: lifecycle.activity != .idle
					)
				}
			}

			SettingsPanel(
				title: "Location"
			) {
				SettingsActionRow(
					title: "Game files",
					detail: (installation.installDirectory.path(percentEncoded: false) as NSString)
						.abbreviatingWithTildeInPath
				) {
					InstallationDownloadStatus(
						installation: installation
					)
					CapsuleActionButton(
						title: "Show in Finder", systemImage: "folder",
						tone: .neutral, presentation: .compact,
						action: installation.revealInstallDirectory
					)
					.disabled(!installation.isInstalled)
					.help("Show game files in Finder")
					GlassActionMenu(
						title: "Change…",
						systemImage: "arrow.triangle.swap",
						isDisabled: !installation.canModifyGameFiles
					) {
						Button(
							"Choose New Location…",
							action: actions.chooseInstallDirectory)
						Button(
							"Locate Existing Installation…",
							action: actions.locateExistingInstallation
						)
					}
				}
			}

			SettingsPanel(
				title: "Maintenance"
			) {
				SettingsActionRow(
					title: "Repair",
					detail: "Check the game files and download anything missing or damaged again."
				) {
					CapsuleActionButton(
						title: "Repair",
						systemImage: "wrench.and.screwdriver",
						tone: .neutral, presentation: .compact,
						action: actions.repairGame
					)
					.disabled(!installation.isInstalled || !installation.canInstall)
				}
			}

			// Shown only while a server needs Canary access. See RegionAccess.
			if GameRegion.allCases.contains(where: \.requiresCanaryPermission) {
				SettingsPanel(
					title: Self.canaryFeaturesTitle,
					tone: .warning
				) {
					SettingsActionRow(
						title: Self.canaryFeaturesTitle,
						detail:
							"Try experimental features before they become stable."
					) {
						SettingsToggle(
							Self.canaryFeaturesTitle,
							isOn: $settings.canaryFeaturesEnabled,
							tint: theme.warning
						)
						.disabled(lifecycle.activity != .idle)
					}
				}
			}

			DangerZonePanel {
				InstallationDestructiveRow(
					title: "Uninstall game",
					detail:
						"Move the game files for \(installation.region.displayName) to the Trash.",
					buttonTitle: "Uninstall Game…",
					systemImage: "trash",
					isDisabled: !installation.canUninstallGame,
					confirming: .uninstallGame(installation.region),
					confirmation: $confirmation
				)
			}
			.installationConfirmation($confirmation, gameSession: gameSession, actions: maintenance)
		}
	}

	private var regionBinding: Binding<GameRegion> {
		Binding(
			get: { installation.region },
			set: { region in actions.selectRegion(region) }
		)
	}
}
