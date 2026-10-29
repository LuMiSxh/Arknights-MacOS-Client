// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsGameRuntime
import SwiftUI

struct InstallationSettingsPage: View {
	private static let canaryFeaturesTitle = "Canary Features"
	@Bindable var settings: LauncherPreferencesController
	package let installation: InstallationController
	let gameSession: GameSessionController
	package let lifecycle: LauncherLifecycleStore
	package let accentColor: Color
	let actions: any LauncherActions
	@State private var confirmation: InstallationConfirmation?

	var body: some View {
		SettingsPage(
			title: "Servers",
			subtitle: "Choose a server and manage its game files",
			accentColor: accentColor
		) {
			SettingsPanel(title: "Server", systemImage: "globe") {
				SettingsActionRow(
					title: "Server",
					detail: "Each server keeps its own game files and updates."
				) {
					GlassMenuPicker(
						selection: regionBinding,
						options: settings.regionAccess.selectableRegions.map {
							($0, $0.displayName)
						},
						accentColor: accentColor,
						isDisabled: lifecycle.activity != .idle
					)
				}
			}

			SettingsPanel(
				title: "Location", systemImage: "externaldrive"
			) {
				SettingsActionRow(
					title: "Status"
				) {
					InstallationDownloadStatus(
						installation: installation,
						accentColor: accentColor
					)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Folder",
					detail: installation.installDirectory.lastPathComponent
				) {
					CapsuleActionButton(
						title: "Show", systemImage: "folder",
						tone: .neutral, presentation: .compact,
						action: installation.revealInstallDirectory
					)
					.disabled(!installation.isInstalled)
					.help("Show game files in Finder")
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Installation location",
					detail: "Move the game to a new folder, or point to a copy you already have."
				) {
					GlassActionMenu(
						title: "Change…",
						systemImage: "arrow.triangle.swap",
						accentColor: accentColor,
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
				title: "Maintenance",
				systemImage: "wrench.and.screwdriver"
			) {
				SettingsActionRow(
					title: "Repair",
					detail: "Check the game files and download anything missing or damaged again."
				) {
					CapsuleActionButton(
						title: "Repair…",
						systemImage: "wrench.and.screwdriver",
						tone: .accent(accentColor), presentation: .compact,
						action: actions.repairGame
					)
					.disabled(!installation.isInstalled || !installation.canInstall)
				}
			}

			SettingsPanel(
				title: Self.canaryFeaturesTitle,
				systemImage: "exclamationmark.triangle.fill",
				tone: .warning
			) {
				SettingsActionRow(
					title: Self.canaryFeaturesTitle,
					detail:
						"Try experimental features. Turning this off switches a Canary server back to Global."
				) {
					SettingsToggle(
						Self.canaryFeaturesTitle,
						isOn: $settings.canaryFeaturesEnabled,
						accentColor: LauncherVisuals.warning
					)
					.disabled(lifecycle.activity != .idle)
				}
				if settings.canaryFeaturesEnabled {
					SettingsHairline()
					canaryRuntimeSettings
				}
			}

			DangerZonePanel {
				InstallationDestructiveRow(
					title: "Uninstall game",
					detail: "Move the game for this server to the Trash.",
					buttonTitle: "Uninstall Game…",
					systemImage: "trash",
					isDisabled: !installation.canUninstallGame,
					confirming: .uninstallGame,
					confirmation: $confirmation
				)
			}
			.installationConfirmation($confirmation, gameSession: gameSession, actions: actions)
		}
	}

	private var regionBinding: Binding<GameRegion> {
		Binding(
			get: { installation.region },
			set: { region in actions.selectRegion(region) }
		)
	}
}
