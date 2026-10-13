// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsGameRuntime
import SwiftUI

struct InstallationSettingsPage: View {
	private static let canaryFeaturesTitle = "Canary Features"
	private static let cancelTitle = "Cancel"

	@Bindable var settings: LauncherPreferencesController
	package let installation: InstallationController
	let gameSession: GameSessionController
	package let lifecycle: LauncherLifecycleStore
	package let accentColor: Color
	let actions: any LauncherActions
	let restartOnboarding: () -> Void
	@State private var confirmsGameUninstall = false
	@State private var confirmsForceMigration = false
	@State private var confirmsWinePrefixDeletion = false
	@State private var confirmsSettingsReset = false

	var body: some View {
		SettingsPage(
			title: "Installation",
			subtitle: "Server, game files, and repairs",
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
					VStack(alignment: .trailing, spacing: 2) {
						Text(gameStatus)
							.foregroundStyle(installation.isDownloading ? accentColor : .secondary)
						transferDetails
					}
					.accessibilityElement(children: .combine)
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
				SettingsHairline()
				SettingsActionRow(
					title: "Setup assistant",
					detail: "Go through the first-run questions again."
				) {
					CapsuleActionButton(
						title: "Run Setup Again…", systemImage: "wand.and.stars",
						tone: .accent(accentColor), presentation: .compact,
						action: restartOnboarding
					)
					.disabled(gameSession.isGameActive)
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
				SettingsActionRow(
					title: "Rebuild game environment",
					detail: "Next launch takes longer. Game files and logins stay.",
					help:
						"Recreates the Wine prefix with its graphics layer and registry overrides."
				) {
					CapsuleActionButton(
						title: "Rebuild…",
						systemImage: "arrow.triangle.2.circlepath",
						tone: .danger,
						presentation: .compact,
						role: .destructive
					) {
						confirmsForceMigration = true
					}
					.disabled(!installation.canModifyGameFiles)
					.confirmationDialog(
						"Rebuild the Game Environment?",
						isPresented: $confirmsForceMigration,
						titleVisibility: .visible
					) {
						Button(
							"Rebuild Environment", role: .destructive,
							action: gameSession.forcePrefixMigration
						)
						Button(Self.cancelTitle, role: .cancel) {}
					} message: {
						Text(
							"Next launch takes longer. Game files and logins stay."
						)
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Reset launcher settings",
					detail:
						"Puts every launcher setting back to its default. Game files, the install location, and the server stay."
				) {
					CapsuleActionButton(
						title: "Reset All Settings…",
						systemImage: "arrow.counterclockwise",
						tone: .danger,
						presentation: .compact,
						role: .destructive
					) {
						confirmsSettingsReset = true
					}
					.disabled(gameSession.isGameActive || lifecycle.activity != .idle)
					.confirmationDialog(
						"Reset All Launcher Settings?",
						isPresented: $confirmsSettingsReset,
						titleVisibility: .visible
					) {
						Button(
							"Reset Settings", role: .destructive,
							action: actions.resetAllLauncherSettings
						)
						Button(Self.cancelTitle, role: .cancel) {}
					} message: {
						Text(
							"Puts every launcher setting back to its default. Game files, the install location, and the server stay."
						)
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Delete game environment",
					detail: "Signs you out of Yostar, Google, Apple and Facebook. Game files stay.",
					help: "Deletes the Wine prefix folder shared by this publisher's servers."
				) {
					CapsuleActionButton(
						title: "Delete Environment…",
						systemImage: "trash",
						tone: .danger,
						presentation: .compact,
						role: .destructive
					) {
						confirmsWinePrefixDeletion = true
					}
					.disabled(!installation.canModifyGameFiles)
					.confirmationDialog(
						"Delete the Game Environment?",
						isPresented: $confirmsWinePrefixDeletion,
						titleVisibility: .visible
					) {
						Button(
							"Delete Environment", role: .destructive,
							action: gameSession.deleteWinePrefix
						)
						Button(Self.cancelTitle, role: .cancel) {}
					} message: {
						Text(
							"This signs you out of every login saved in the sign-in window. Game files are untouched."
						)
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Uninstall game",
					detail: "Move the game for this server to the Trash."
				) {
					CapsuleActionButton(
						title: "Uninstall Game…",
						systemImage: "trash",
						tone: .danger,
						presentation: .compact,
						role: .destructive
					) {
						confirmsGameUninstall = true
					}
					.disabled(!installation.canUninstallGame)
					.confirmationDialog(
						"Uninstall Arknights?",
						isPresented: $confirmsGameUninstall,
						titleVisibility: .visible
					) {
						Button(
							"Move Game to Trash", role: .destructive,
							action: actions.uninstallGame)
						Button(Self.cancelTitle, role: .cancel) {}
					} message: {
						Text("The launcher stays installed.")
					}
				}
			}
		}
	}

	private var gameStatus: String {
		if installation.isDownloading, let progress = installation.progress {
			let percentage = Int(progress.fraction * 100)
			return progress.isVerifying
				? "Verifying \(percentage)%" : "Downloading \(percentage)%"
		}
		if installation.isDownloading { return "Preparing download" }
		if installation.isInstalled { return "Installed" }
		return
			installation.hasPartialDownload ? "Paused" : "Not installed"
	}

	private var regionBinding: Binding<GameRegion> {
		Binding(
			get: { installation.region },
			set: { region in actions.selectRegion(region) }
		)
	}
}
