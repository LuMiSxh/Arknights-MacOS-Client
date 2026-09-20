// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct InstallationSettingsPage: View {
	@Bindable var settings: LauncherPreferencesController
	let installation: InstallationController
	let gameSession: GameSessionController
	let lifecycle: LauncherLifecycleStore
	let accentColor: Color
	let selectRegion: (GameRegion) -> Void
	let chooseInstallDirectory: () -> Void
	let locateExistingInstallation: () -> Void
	let repairGame: () -> Void
	let resetAllLauncherSettings: () -> Void
	let uninstallGame: () -> Void
	@State private var confirmsGameUninstall = false
	@State private var confirmsForceMigration = false
	@State private var confirmsWinePrefixDeletion = false
	@State private var confirmsSettingsReset = false
	@State private var showsGameModeUnavailableAlert = false

	var body: some View {
		SettingsPage(
			title: SettingsStrings.installationTitle,
			subtitle: SettingsStrings.installationSubtitle,
			accentColor: accentColor
		) {
			SettingsPanel(title: SettingsStrings.region, systemImage: "globe") {
				SettingsActionRow(
					title: SettingsStrings.region,
					detail: SettingsStrings.regionDetail
				) {
					GlassMenuPicker(
						selection: regionBinding,
						options: GameRegion.selectableCases(
							canaryEnabled: settings.canaryFeaturesEnabled,
							chinaClientsEnabled: settings.chinaClientsEnabled,
							taiwanClientEnabled: settings.taiwanClientEnabled
						).map { ($0, $0.displayName) },
						accentColor: accentColor,
						isDisabled: lifecycle.activity != .idle
					)
				}
			}

			SettingsPanel(
				title: SettingsStrings.location, systemImage: "externaldrive"
			) {
				SettingsActionRow(
					title: SettingsStrings.status,
					detail: SettingsStrings.statusDetail
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
					title: SettingsStrings.folder,
					detail: installation.installDirectory.lastPathComponent
				) {
					CapsuleActionButton(
						title: SettingsStrings.show, systemImage: "folder",
						tone: .accent(accentColor), presentation: .compact,
						action: installation.revealInstallDirectory
					)
					.disabled(!installation.isInstalled)
					.help(SettingsStrings.showGameFilesHelp)
				}
				SettingsHairline()
				SettingsActionRow(
					title: SettingsStrings.installationLocation,
					detail: SettingsStrings.installationLocationDetail
				) {
					GlassActionMenu(
						title: SettingsStrings.change,
						systemImage: "arrow.triangle.swap",
						accentColor: accentColor,
						isDisabled: !installation.canModifyGameFiles
					) {
						Button(
							SettingsStrings.chooseNewLocation,
							action: chooseInstallDirectory)
						Button(
							SettingsStrings.locateExisting,
							action: locateExistingInstallation
						)
					}
				}
			}

			SettingsPanel(
				title: SettingsStrings.maintenance,
				systemImage: "wrench.and.screwdriver"
			) {
				SettingsActionRow(
					title: SettingsStrings.repair,
					detail: SettingsStrings.repairDetail
				) {
					CapsuleActionButton(
						title: SettingsStrings.repairAction,
						systemImage: "wrench.and.screwdriver",
						tone: .accent(accentColor), presentation: .compact,
						action: repairGame
					)
					.disabled(!installation.isInstalled || !installation.canInstall)
				}
			}

			SettingsPanel(
				title: SettingsStrings.compatibility,
				systemImage: "slider.horizontal.2.square"
			) {
				SettingsActionRow(
					title: SettingsStrings.metalHUD,
					detail: SettingsStrings.metalHUDDetail
				) {
					SettingsToggle(
						SettingsStrings.metalHUD,
						isOn: $settings.launchOptions.usesMetalPerformanceHUD,
						accentColor: accentColor
					)
					.disabled(gameSession.isGameActive)
				}
				SettingsHairline()
				SettingsActionRow(
					title: SettingsStrings.gameMode,
					detail: SettingsStrings.gameModeDetail
				) {
					SettingsToggle(
						SettingsStrings.gameMode,
						isOn: gameModeBinding,
						accentColor: accentColor
					)
					.disabled(gameSession.isGameActive)
					.alert(
						SettingsStrings.gameModeAlert,
						isPresented: $showsGameModeUnavailableAlert
					) {
					} message: {
						Text(SettingsStrings.gameModeAlertDetail)
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: SettingsStrings.wineSynchronization,
					detail: SettingsStrings.wineSynchronizationDetail
				) {
					AdaptiveSegmentedControl(
						selection: $settings.launchOptions.synchronizationMode,
						options: WineSynchronizationMode.allCases,
						accentColor: accentColor,
						isDisabled: gameSession.isGameActive
					) { mode in
						Text(mode.displayName)
					}
				}
			}

			SettingsPanel(
				title: SettingsStrings.canaryFeatures,
				systemImage: "exclamationmark.triangle.fill",
				tone: .warning
			) {
				SettingsActionRow(
					title: SettingsStrings.canaryFeatures,
					detail: SettingsStrings.canaryFeaturesDetail
				) {
					SettingsToggle(
						SettingsStrings.canaryFeatures,
						isOn: $settings.canaryFeaturesEnabled,
						accentColor: LauncherVisuals.warning
					)
					.disabled(lifecycle.activity != .idle)
				}
				if settings.canaryFeaturesEnabled {
					canaryRuntimeSettings
				}
			}

			DangerZonePanel {
				SettingsHairline()
				SettingsActionRow(
					title: SettingsStrings.wineSetup,
					detail: SettingsStrings.forceMigrationDetail
				) {
					CapsuleActionButton(
						title: SettingsStrings.forceMigrationAction, tone: .danger,
						presentation: .compact,
						role: .destructive
					) {
						confirmsForceMigration = true
					}
					.disabled(!installation.canModifyGameFiles)
					.confirmationDialog(
						SettingsStrings.forceMigrationConfirmation,
						isPresented: $confirmsForceMigration,
						titleVisibility: .visible
					) {
						Button(
							SettingsStrings.forceMigration, role: .destructive,
							action: gameSession.forcePrefixMigration
						)
						Button(SettingsStrings.cancel, role: .cancel) {}
					} message: {
						Text(SettingsStrings.forceMigrationDetail)
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: SettingsStrings.launcherSettings,
					detail: SettingsStrings.resetSettingsDetail
				) {
					CapsuleActionButton(
						title: SettingsStrings.resetSettingsAction, tone: .danger,
						presentation: .compact,
						role: .destructive
					) {
						confirmsSettingsReset = true
					}
					.disabled(gameSession.isGameActive || lifecycle.activity != .idle)
					.confirmationDialog(
						SettingsStrings.resetSettingsConfirmation,
						isPresented: $confirmsSettingsReset,
						titleVisibility: .visible
					) {
						Button(
							SettingsStrings.resetSettings, role: .destructive,
							action: resetAllLauncherSettings
						)
						Button(SettingsStrings.cancel, role: .cancel) {}
					} message: {
						Text(SettingsStrings.resetSettingsDetail)
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: SettingsStrings.winePrefix,
					detail: SettingsStrings.winePrefixDetail
				) {
					CapsuleActionButton(
						title: SettingsStrings.deleteWinePrefix, tone: .danger,
						presentation: .compact,
						role: .destructive
					) {
						confirmsWinePrefixDeletion = true
					}
					.disabled(!installation.canModifyGameFiles)
					.confirmationDialog(
						SettingsStrings.deleteWinePrefixConfirmation,
						isPresented: $confirmsWinePrefixDeletion,
						titleVisibility: .visible
					) {
						Button(
							SettingsStrings.deleteWinePrefixAction, role: .destructive,
							action: gameSession.deleteWinePrefix
						)
						Button(SettingsStrings.cancel, role: .cancel) {}
					} message: {
						Text(SettingsStrings.deleteWinePrefixDetail)
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: SettingsStrings.gameFiles,
					detail: SettingsStrings.gameFilesDetail
				) {
					CapsuleActionButton(
						title: SettingsStrings.uninstall, tone: .danger,
						presentation: .compact,
						role: .destructive
					) {
						confirmsGameUninstall = true
					}
					.disabled(!installation.isInstalled || !installation.canModifyGameFiles)
					.confirmationDialog(
						SettingsStrings.uninstallConfirmation,
						isPresented: $confirmsGameUninstall,
						titleVisibility: .visible
					) {
						Button(
							SettingsStrings.moveGameToTrash, role: .destructive,
							action: uninstallGame)
						Button(SettingsStrings.cancel, role: .cancel) {}
					} message: {
						Text(SettingsStrings.uninstallDetail)
					}
				}
			}
		}
	}

	private var gameModeBinding: Binding<Bool> {
		Binding(
			get: { settings.launchOptions.usesGameMode },
			set: { newValue in
				if newValue, !GamePolicyControl.isAvailable() {
					showsGameModeUnavailableAlert = true
					return
				}
				settings.launchOptions.usesGameMode = newValue
			}
		)
	}

	private var gameStatus: String {
		if installation.isDownloading, let progress = installation.progress {
			return SettingsStrings.downloading(Int(progress.fraction * 100))
		}
		if installation.isDownloading { return SettingsStrings.preparingDownload }
		if installation.isInstalled { return SettingsStrings.installed }
		return
			installation.hasPartialDownload ? SettingsStrings.paused : SettingsStrings.notInstalled
	}

	private var regionBinding: Binding<GameRegion> {
		Binding(
			get: { installation.region },
			set: { region in selectRegion(region) }
		)
	}
}
