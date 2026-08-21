// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct InstallationSettingsPage: View {
	var model: LauncherViewModel
	@State private var confirmsGameUninstall = false
	@State private var confirmsForceMigration = false
	@State private var confirmsWinePrefixDeletion = false
	@State private var confirmsSettingsReset = false
	@State private var showsGameModeUnavailableAlert = false

	var body: some View {
		SettingsPage(
			title: "Installation", subtitle: "Files, repair, and removal",
			accentColor: model.accentColor
		) {
			SettingsPanel(title: "Region", systemImage: "globe") {
				SettingsActionRow(
					title: "Region",
					detail: "Global, Japan, and Korea install, update, and launch independently."
				) {
					GlassMenuPicker(
						selection: regionBinding,
						options: GameRegion.allCases.map { ($0, $0.displayName) },
						accentColor: model.accentColor,
						isDisabled: !model.canSwitchRegion
					)
				}
			}

			SettingsPanel(title: "Location", systemImage: "externaldrive") {
				SettingsActionRow(
					title: "Status",
					detail: "State of the selected region's game installation."
				) {
					Text(gameStatus)
						.foregroundStyle(model.isDownloading ? model.accentColor : .secondary)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Folder",
					detail: model.installDirectory.lastPathComponent
				) {
					CapsuleActionButton(
						title: "Show", systemImage: "folder",
						tone: .accent(model.accentColor), presentation: .compact,
						action: model.revealInstallDirectory
					)
					.disabled(!model.isInstalled)
					.help("Show game files in Finder")
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Installation Location",
					detail: "Choose a new folder or adopt an existing game installation."
				) {
					GlassActionMenu(
						title: "Change…",
						systemImage: "arrow.triangle.swap",
						accentColor: model.accentColor,
						isDisabled: !model.canModifyGameFiles
					) {
						Button("Choose New Location…", action: model.chooseInstallDirectory)
						Button(
							"Locate Existing Installation…",
							action: model.locateExistingInstallation
						)
					}
				}
			}

			SettingsPanel(title: "Maintenance", systemImage: "wrench.and.screwdriver") {
				SettingsActionRow(
					title: "Repair",
					detail: "Check every game file and download missing or damaged files again."
				) {
					CapsuleActionButton(
						"Repair…", systemImage: "wrench.and.screwdriver",
						tone: .accent(model.accentColor), presentation: .compact,
						action: model.repairGame
					)
					.disabled(!model.isInstalled || !model.canInstall)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Clear Cache",
					detail:
						"Free \(model.cacheSizeText) used by shader and browser caches. They rebuild automatically."
				) {
					CapsuleActionButton(
						title: "Clear Cache…", systemImage: "trash",
						tone: .accent(model.accentColor), presentation: .compact,
						action: model.clearCache
					)
					.disabled(!model.canModifyGameFiles)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Preset Gallery Caches",
					detail:
						"Clear cached preset metadata and all downloaded gallery assets (avatars + wallpapers). They currently use \(model.presetGalleryCacheSizeText)."
				) {
					CapsuleActionButton(
						title: "Clear Cache...", systemImage: "trash",
						tone: .accent(model.accentColor), presentation: .compact
					) {
						model.clearPresetGalleryCache()
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Logs",
					detail: "Use these files when reporting startup or game problems."
				) {
					CapsuleActionButton(
						"Show Logs", systemImage: "doc.text.magnifyingglass",
						tone: .accent(model.accentColor), presentation: .compact,
						action: model.revealLogs
					)
				}
			}

			DangerZonePanel {
				SettingsActionRow(
					title: "Game Mode (Experimental)",
					detail:
						"Asks macOS to prioritize the game while it runs. Needs the full Xcode app installed, since only Xcode ships the tool this requires."
				) {
					Toggle("Game Mode", isOn: gameModeBinding)
						.labelsHidden()
						.toggleStyle(.switch)
						.tint(LauncherVisuals.danger)
						.alert("Game Mode Needs Xcode", isPresented: $showsGameModeUnavailableAlert)
					{
					} message: {
						Text(
							"This requires Apple's gamepolicyctl tool, which only ships inside the full Xcode app, not the Command Line Tools. Install Xcode from the App Store to use it."
						)
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Launcher Settings",
					detail:
						"Reset every toggle and option on this screen to default. The install location and selected region are untouched."
				) {
					CapsuleActionButton(
						title: "Reset All Settings…", tone: .danger, presentation: .compact,
						role: .destructive
					) {
						confirmsSettingsReset = true
					}
					.confirmationDialog(
						"Reset All Launcher Settings?",
						isPresented: $confirmsSettingsReset,
						titleVisibility: .visible
					) {
						Button(
							"Reset Settings", role: .destructive,
							action: model.resetAllLauncherSettings
						)
						Button("Cancel", role: .cancel) {}
					} message: {
						Text("The install location and selected region are untouched.")
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Wine Setup",
					detail:
						"Redo Wine initialization, DXMT installation, and registry overrides on the next launch. Game files and saves are untouched; only the next launch takes longer."
				) {
					CapsuleActionButton(
						title: "Force Migration…", tone: .danger, presentation: .compact,
						role: .destructive
					) {
						confirmsForceMigration = true
					}
					.disabled(!model.canModifyGameFiles)
					.confirmationDialog(
						"Force Wine Setup to Run Again?",
						isPresented: $confirmsForceMigration,
						titleVisibility: .visible
					) {
						Button(
							"Force Migration", role: .destructive,
							action: model.forcePrefixMigration
						)
						Button("Cancel", role: .cancel) {}
					} message: {
						Text(
							"Game files and saves stay untouched; only the next launch takes longer."
						)
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Wine Prefix",
					detail:
						"Delete the entire Wine environment, including saved Yostar, Google, Apple, and Facebook logins. Game files are untouched; everything else rebuilds on the next launch."
				) {
					CapsuleActionButton(
						title: "Delete Wine Prefix…", tone: .danger, presentation: .compact,
						role: .destructive
					) {
						confirmsWinePrefixDeletion = true
					}
					.disabled(!model.canModifyGameFiles)
					.confirmationDialog(
						"Delete the Wine Prefix?",
						isPresented: $confirmsWinePrefixDeletion,
						titleVisibility: .visible
					) {
						Button(
							"Delete Wine Prefix", role: .destructive, action: model.deleteWinePrefix
						)
						Button("Cancel", role: .cancel) {}
					} message: {
						Text(
							"This signs you out of every login saved in the embedded browser. Game files are untouched."
						)
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Game files",
					detail: "Move the selected game installation to the Trash."
				) {
					CapsuleActionButton(
						title: "Uninstall Game…", tone: .danger, presentation: .compact,
						role: .destructive
					) {
						confirmsGameUninstall = true
					}
					.disabled(!model.isInstalled || !model.canModifyGameFiles)
					.confirmationDialog(
						"Uninstall Arknights?",
						isPresented: $confirmsGameUninstall,
						titleVisibility: .visible
					) {
						Button(
							"Move Game to Trash", role: .destructive, action: model.uninstallGame)
						Button("Cancel", role: .cancel) {}
					} message: {
						Text("The launcher stays installed.")
					}
				}
			}
		}
	}

	private var gameModeBinding: Binding<Bool> {
		Binding(
			get: { model.launchOptions.usesGameMode },
			set: { newValue in
				if newValue, !GamePolicyControl.isAvailable() {
					showsGameModeUnavailableAlert = true
					return
				}
				model.launchOptions.usesGameMode = newValue
			}
		)
	}

	private var gameStatus: String {
		if model.isDownloading, let progress = model.progress {
			return "Downloading \(Int(progress.fraction * 100))%"
		}
		if model.isDownloading { return "Preparing download" }
		if model.isInstalled { return "Installed" }
		return model.hasPartialDownload ? "Paused" : "Not installed"
	}

	private var regionBinding: Binding<GameRegion> {
		Binding(get: { model.region }, set: { model.selectRegion($0) })
	}
}
