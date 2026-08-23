// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct InstallationSettingsPage: View {
	@Bindable var settings: LauncherPreferencesController
	let installation: InstallationController
	let storage: StorageMaintenanceController
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
			title: L10n.string(SettingsStrings.installationTitle),
			subtitle: L10n.string(SettingsStrings.installationSubtitle),
			accentColor: accentColor
		) {
			SettingsPanel(title: L10n.string(SettingsStrings.region), systemImage: "globe") {
				SettingsActionRow(
					title: L10n.string(SettingsStrings.region),
					detail: L10n.string(SettingsStrings.regionDetail)
				) {
					GlassMenuPicker(
						selection: regionBinding,
						options: GameRegion.allCases.map { ($0, $0.localizedDisplayName) },
						accentColor: accentColor,
						isDisabled: lifecycle.activity != .idle
					)
				}
			}

			SettingsPanel(
				title: L10n.string(SettingsStrings.location), systemImage: "externaldrive"
			) {
				SettingsActionRow(
					title: L10n.string(SettingsStrings.status),
					detail: L10n.string(SettingsStrings.statusDetail)
				) {
					Text(gameStatus)
						.foregroundStyle(installation.isDownloading ? accentColor : .secondary)
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.folder),
					detail: installation.installDirectory.lastPathComponent
				) {
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.show), systemImage: "folder",
						tone: .accent(accentColor), presentation: .compact,
						action: installation.revealInstallDirectory
					)
					.disabled(!installation.isInstalled)
					.help(L10n.string(SettingsStrings.showGameFilesHelp))
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.installationLocation),
					detail: L10n.string(SettingsStrings.installationLocationDetail)
				) {
					GlassActionMenu(
						title: L10n.string(SettingsStrings.change),
						systemImage: "arrow.triangle.swap",
						accentColor: accentColor,
						isDisabled: !installation.canModifyGameFiles
					) {
						Button(
							L10n.string(SettingsStrings.chooseNewLocation),
							action: chooseInstallDirectory)
						Button(
							L10n.string(SettingsStrings.locateExisting),
							action: locateExistingInstallation
						)
					}
				}
			}

			SettingsPanel(
				title: L10n.string(SettingsStrings.maintenance),
				systemImage: "wrench.and.screwdriver"
			) {
				SettingsActionRow(
					title: L10n.string(SettingsStrings.repair),
					detail: L10n.string(SettingsStrings.repairDetail)
				) {
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.repairAction),
						systemImage: "wrench.and.screwdriver",
						tone: .accent(accentColor), presentation: .compact,
						action: repairGame
					)
					.disabled(!installation.isInstalled || !installation.canInstall)
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.clearCache),
					detail: L10n.string(SettingsStrings.cacheDetail(storage.gameCacheSizeText))
				) {
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.clearCache), systemImage: "trash",
						tone: .accent(accentColor), presentation: .compact,
						action: storage.clearGameCache
					)
					.disabled(!installation.canModifyGameFiles)
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.cacheGallery),
					detail: L10n.string(
						SettingsStrings.cacheGalleryDetail(storage.presetGalleryCacheSizeText))
				) {
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.clearCache), systemImage: "trash",
						tone: .accent(accentColor), presentation: .compact
					) {
						storage.clearPresetGalleryCache()
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.logs),
					detail: L10n.string(SettingsStrings.logsDetail)
				) {
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.showLogs),
						systemImage: "doc.text.magnifyingglass",
						tone: .accent(accentColor), presentation: .compact,
						action: storage.revealLogs
					)
				}
			}

			DangerZonePanel {
				SettingsActionRow(
					title: L10n.string(SettingsStrings.gameMode),
					detail: L10n.string(SettingsStrings.gameModeDetail)
				) {
					Toggle(L10n.string(SettingsStrings.gameMode), isOn: gameModeBinding)
						.labelsHidden()
						.toggleStyle(.switch)
						.tint(LauncherVisuals.danger)
						.disabled(gameSession.isGameActive)
						.alert(
							L10n.string(SettingsStrings.gameModeAlert),
							isPresented: $showsGameModeUnavailableAlert
						) {
						} message: {
							Text(
								SettingsStrings.gameModeAlertDetail
							)
						}
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.wineSynchronization),
					detail: L10n.string(SettingsStrings.wineSynchronizationDetail)
				) {
					AdaptiveSegmentedControl(
						selection: $settings.launchOptions.synchronizationMode,
						options: WineSynchronizationMode.allCases,
						accentColor: LauncherVisuals.danger,
						isDisabled: gameSession.isGameActive
					) { mode in
						Text(mode.displayName)
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.wineSetup),
					detail: L10n.string(SettingsStrings.forceMigrationDetail)
				) {
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.forceMigrationAction), tone: .danger,
						presentation: .compact,
						role: .destructive
					) {
						confirmsForceMigration = true
					}
					.disabled(!installation.canModifyGameFiles)
					.confirmationDialog(
						L10n.string(SettingsStrings.forceMigrationConfirmation),
						isPresented: $confirmsForceMigration,
						titleVisibility: .visible
					) {
						Button(
							L10n.string(SettingsStrings.forceMigration), role: .destructive,
							action: gameSession.forcePrefixMigration
						)
						Button(L10n.string(SettingsStrings.cancel), role: .cancel) {}
					} message: {
						Text(
							SettingsStrings.forceMigrationDetail
						)
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.launcherSettings),
					detail: L10n.string(SettingsStrings.resetSettingsDetail)
				) {
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.resetSettingsAction), tone: .danger,
						presentation: .compact,
						role: .destructive
					) {
						confirmsSettingsReset = true
					}
					.disabled(gameSession.isGameActive)
					.confirmationDialog(
						L10n.string(SettingsStrings.resetSettingsConfirmation),
						isPresented: $confirmsSettingsReset,
						titleVisibility: .visible
					) {
						Button(
							L10n.string(SettingsStrings.resetSettings), role: .destructive,
							action: resetAllLauncherSettings
						)
						Button(L10n.string(SettingsStrings.cancel), role: .cancel) {}
					} message: {
						Text(SettingsStrings.resetSettingsDetail)
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.winePrefix),
					detail: L10n.string(SettingsStrings.winePrefixDetail)
				) {
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.deleteWinePrefix), tone: .danger,
						presentation: .compact,
						role: .destructive
					) {
						confirmsWinePrefixDeletion = true
					}
					.disabled(!installation.canModifyGameFiles)
					.confirmationDialog(
						L10n.string(SettingsStrings.deleteWinePrefixConfirmation),
						isPresented: $confirmsWinePrefixDeletion,
						titleVisibility: .visible
					) {
						Button(
							L10n.string(SettingsStrings.deleteWinePrefixAction), role: .destructive,
							action: gameSession.deleteWinePrefix
						)
						Button(L10n.string(SettingsStrings.cancel), role: .cancel) {}
					} message: {
						Text(SettingsStrings.deleteWinePrefixDetail)
					}
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.gameFiles),
					detail: L10n.string(SettingsStrings.gameFilesDetail)
				) {
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.uninstall), tone: .danger,
						presentation: .compact,
						role: .destructive
					) {
						confirmsGameUninstall = true
					}
					.disabled(!installation.isInstalled || !installation.canModifyGameFiles)
					.confirmationDialog(
						L10n.string(SettingsStrings.uninstallConfirmation),
						isPresented: $confirmsGameUninstall,
						titleVisibility: .visible
					) {
						Button(
							L10n.string(SettingsStrings.moveGameToTrash), role: .destructive,
							action: uninstallGame)
						Button(L10n.string(SettingsStrings.cancel), role: .cancel) {}
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
			return L10n.string(SettingsStrings.downloading(Int(progress.fraction * 100)))
		}
		if installation.isDownloading { return L10n.string(SettingsStrings.preparingDownload) }
		if installation.isInstalled { return L10n.string(SettingsStrings.installed) }
		return L10n.string(
			installation.hasPartialDownload ? SettingsStrings.paused : SettingsStrings.notInstalled)
	}

	private var regionBinding: Binding<GameRegion> {
		Binding(
			get: { installation.region },
			set: { region in selectRegion(region) }
		)
	}
}
