// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsGameRuntime
import SwiftUI

struct InstallationSettingsPage: View {
	private static let canaryFeaturesTitle = "Canary Features"
	private static let cancelTitle = "Cancel"
	private static let rebuildDetail =
		"Next launch takes longer. Game files and logins stay."
	private static let settingsResetDetail =
		"Puts every launcher setting back to its default. Game files, the install location, and the server stay."

	@Bindable var settings: LauncherPreferencesController
	package let installation: InstallationController
	let gameSession: GameSessionController
	package let lifecycle: LauncherLifecycleStore
	package let accentColor: Color
	let actions: any LauncherActions
	let restartOnboarding: () -> Void
	@State private var confirmation: InstallationConfirmation?

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
				destructiveRow(
					title: "Rebuild game environment",
					detail: Self.rebuildDetail,
					help:
						"Recreates the Wine prefix with its graphics layer and registry overrides.",
					buttonTitle: "Rebuild…",
					systemImage: "arrow.triangle.2.circlepath",
					isDisabled: !installation.canModifyGameFiles,
					confirming: .rebuildEnvironment
				)
				SettingsHairline()
				destructiveRow(
					title: "Reset launcher settings",
					detail: Self.settingsResetDetail,
					buttonTitle: "Reset All Settings…",
					systemImage: "arrow.counterclockwise",
					isDisabled: gameSession.isGameActive || lifecycle.activity != .idle,
					confirming: .resetSettings
				)
				SettingsHairline()
				destructiveRow(
					title: "Delete game environment",
					detail: "Signs you out of Yostar, Google, Apple and Facebook. Game files stay.",
					help: "Deletes the Wine prefix folder shared by this publisher's servers.",
					buttonTitle: "Delete Environment…",
					systemImage: "trash",
					isDisabled: !installation.canModifyGameFiles,
					confirming: .deleteEnvironment
				)
				SettingsHairline()
				destructiveRow(
					title: "Uninstall game",
					detail: "Move the game for this server to the Trash.",
					buttonTitle: "Uninstall Game…",
					systemImage: "trash",
					isDisabled: !installation.canUninstallGame,
					confirming: .uninstallGame
				)
			}
			.confirmationDialog(
				confirmation?.title ?? "",
				isPresented: isConfirmingBinding,
				titleVisibility: .visible
			) {
				Button(confirmation?.confirmTitle ?? "", role: .destructive) {
					if let confirmation { perform(confirmation) }
				}
				Button(Self.cancelTitle, role: .cancel) {}
			} message: {
				Text(confirmation?.message ?? "")
			}
		}
	}

	private func destructiveRow(
		title: String,
		detail: String,
		help: String? = nil,
		buttonTitle: String,
		systemImage: String,
		isDisabled: Bool,
		confirming request: InstallationConfirmation
	) -> some View {
		SettingsActionRow(title: title, detail: detail, help: help) {
			CapsuleActionButton(
				title: buttonTitle,
				systemImage: systemImage,
				tone: .danger,
				presentation: .compact,
				role: .destructive
			) {
				confirmation = request
			}
			.disabled(isDisabled)
		}
	}

	private var isConfirmingBinding: Binding<Bool> {
		Binding(
			get: { confirmation != nil },
			set: { isPresented in
				if !isPresented { confirmation = nil }
			}
		)
	}

	private func perform(_ confirmation: InstallationConfirmation) {
		switch confirmation {
		case .rebuildEnvironment: gameSession.forcePrefixMigration()
		case .resetSettings: actions.resetAllLauncherSettings()
		case .deleteEnvironment: gameSession.deleteWinePrefix()
		case .uninstallGame: actions.uninstallGame()
		}
	}

	private enum InstallationConfirmation {
		case rebuildEnvironment, resetSettings, deleteEnvironment, uninstallGame

		var title: String {
			switch self {
			case .rebuildEnvironment: "Rebuild the Game Environment?"
			case .resetSettings: "Reset All Launcher Settings?"
			case .deleteEnvironment: "Delete the Game Environment?"
			case .uninstallGame: "Uninstall Arknights?"
			}
		}

		var confirmTitle: String {
			switch self {
			case .rebuildEnvironment: "Rebuild Environment"
			case .resetSettings: "Reset Settings"
			case .deleteEnvironment: "Delete Environment"
			case .uninstallGame: "Move Game to Trash"
			}
		}

		var message: String {
			switch self {
			case .rebuildEnvironment: InstallationSettingsPage.rebuildDetail
			case .resetSettings: InstallationSettingsPage.settingsResetDetail
			case .deleteEnvironment:
				"This signs you out of every login saved in the sign-in window. Game files are untouched."
			case .uninstallGame: "The launcher stays installed."
			}
		}
	}

	private var regionBinding: Binding<GameRegion> {
		Binding(
			get: { installation.region },
			set: { region in actions.selectRegion(region) }
		)
	}
}
