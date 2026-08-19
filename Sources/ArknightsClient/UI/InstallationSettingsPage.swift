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
				LabeledContent("Region") {
					GlassMenuPicker(
						selection: regionBinding,
						options: GameRegion.allCases.map { ($0, $0.displayName) },
						accentColor: model.accentColor,
						isDisabled: !model.canSwitchRegion
					)
				}
				.help("Global, Japan, and Korea install, update, and launch independently")
			}

			SettingsPanel(title: "Location", systemImage: "externaldrive") {
				LabeledContent("Status") {
					Text(gameStatus)
						.foregroundStyle(model.isDownloading ? model.accentColor : .secondary)
				}
				SettingsHairline()
				LabeledContent("Folder") {
					HStack(spacing: 10) {
						Text(model.installDirectory.lastPathComponent)
							.lineLimit(1)
							.truncationMode(.middle)
							.help(model.installDirectory.path)
						Button("Show", systemImage: "folder", action: model.revealInstallDirectory)
							.labelStyle(.iconOnly)
							.disabled(!model.isInstalled)
							.help("Show game files in Finder")
					}
				}
				SettingsHairline()
				HStack {
					Menu("Installation Location", systemImage: "arrow.triangle.swap") {
						Button("Choose New Location…", action: model.chooseInstallDirectory)
						Button(
							"Locate Existing Installation…",
							action: model.locateExistingInstallation
						)
					}
					.disabled(model.isDownloading)
					Spacer()
				}
			}

			SettingsPanel(title: "Maintenance", systemImage: "wrench.and.screwdriver") {
				SettingsActionRow(
					title: "Repair",
					detail: "Check every game file and download missing or damaged files again."
				) {
					Button(
						"Repair…", systemImage: "wrench.and.screwdriver", action: model.repairGame
					)
					.disabled(!model.isInstalled || !model.canInstall)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Clear Cache",
					detail:
						"Free \(model.cacheSizeText) used by shader and browser caches. They rebuild automatically."
				) {
					Button("Clear Cache…", systemImage: "trash", action: model.clearCache)
						.disabled(model.isGameActive)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Logs",
					detail: "Use these files when reporting startup or game problems."
				) {
					Button(
						"Show Logs", systemImage: "doc.text.magnifyingglass",
						action: model.revealLogs)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "Report a Problem",
					detail: "Open a pre-filled bug report on GitHub."
				) {
					Button {
						NSWorkspace.shared.open(IssueReportURL.build())
					} label: {
						Label("Report…", systemImage: "ladybug")
					}
					.adaptiveGlassButton()
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
						.tint(SettingsVisuals.danger)
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
					Button("Reset All Settings…", role: .destructive) {
						confirmsSettingsReset = true
					}
					.tint(SettingsVisuals.danger)
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
					Button("Force Migration…", role: .destructive) {
						confirmsForceMigration = true
					}
					.tint(SettingsVisuals.danger)
					.disabled(model.isDownloading || model.isGameActive)
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
					Button("Delete Wine Prefix…", role: .destructive) {
						confirmsWinePrefixDeletion = true
					}
					.tint(SettingsVisuals.danger)
					.disabled(model.isDownloading || model.isGameActive)
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
					Button("Uninstall Game…", role: .destructive) {
						confirmsGameUninstall = true
					}
					.tint(SettingsVisuals.danger)
					.disabled(!model.isInstalled || model.isDownloading)
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
