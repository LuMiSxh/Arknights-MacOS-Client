// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct InstallationSettingsPage: View {
	@Bindable var model: LauncherViewModel
	@State private var confirmsGameUninstall = false
	@State private var confirmsForceMigration = false
	@State private var confirmsWinePrefixDeletion = false
	@State private var confirmsSettingsReset = false
	@State private var showsGameModeUnavailableAlert = false

	var body: some View {
		SettingsPage(
			title: L10n.string(SettingsStrings.installationTitle),
			subtitle: L10n.string(SettingsStrings.installationSubtitle),
			accentColor: model.accentColor
		) {
			SettingsPanel(title: L10n.string(SettingsStrings.region), systemImage: "globe") {
				SettingsActionRow(
					title: L10n.string(SettingsStrings.region),
					detail: L10n.string(SettingsStrings.regionDetail)
				) {
					GlassMenuPicker(
						selection: regionBinding,
						options: GameRegion.allCases.map { ($0, $0.localizedDisplayName) },
						accentColor: model.accentColor,
						isDisabled: !model.canSwitchRegion
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
						.foregroundStyle(model.isDownloading ? model.accentColor : .secondary)
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.folder),
					detail: model.installDirectory.lastPathComponent
				) {
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.show), systemImage: "folder",
						tone: .accent(model.accentColor), presentation: .compact,
						action: model.revealInstallDirectory
					)
					.disabled(!model.isInstalled)
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
						accentColor: model.accentColor,
						isDisabled: !model.canModifyGameFiles
					) {
						Button(
							L10n.string(SettingsStrings.chooseNewLocation),
							action: model.chooseInstallDirectory)
						Button(
							L10n.string(SettingsStrings.locateExisting),
							action: model.locateExistingInstallation
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
						tone: .accent(model.accentColor), presentation: .compact,
						action: model.repairGame
					)
					.disabled(!model.isInstalled || !model.canInstall)
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.clearCache),
					detail: L10n.string(SettingsStrings.cacheDetail(model.cacheSizeText))
				) {
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.clearCache), systemImage: "trash",
						tone: .accent(model.accentColor), presentation: .compact,
						action: model.clearCache
					)
					.disabled(!model.canModifyGameFiles)
				}
				SettingsHairline()
				SettingsActionRow(
					title: L10n.string(SettingsStrings.cacheGallery),
					detail: L10n.string(
						SettingsStrings.cacheGalleryDetail(model.presetGalleryCacheSizeText))
				) {
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.clearCache), systemImage: "trash",
						tone: .accent(model.accentColor), presentation: .compact
					) {
						model.clearPresetGalleryCache()
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
						tone: .accent(model.accentColor), presentation: .compact,
						action: model.revealLogs
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
						.disabled(!model.canModifyLaunchOptions)
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
						selection: $model.launchOptions.synchronizationMode,
						options: WineSynchronizationMode.allCases,
						accentColor: LauncherVisuals.danger,
						isDisabled: !model.canModifyLaunchOptions
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
					.disabled(!model.canModifyGameFiles)
					.confirmationDialog(
						L10n.string(SettingsStrings.forceMigrationConfirmation),
						isPresented: $confirmsForceMigration,
						titleVisibility: .visible
					) {
						Button(
							L10n.string(SettingsStrings.forceMigration), role: .destructive,
							action: model.forcePrefixMigration
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
					.disabled(!model.canModifyLaunchOptions)
					.confirmationDialog(
						L10n.string(SettingsStrings.resetSettingsConfirmation),
						isPresented: $confirmsSettingsReset,
						titleVisibility: .visible
					) {
						Button(
							L10n.string(SettingsStrings.resetSettings), role: .destructive,
							action: model.resetAllLauncherSettings
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
					.disabled(!model.canModifyGameFiles)
					.confirmationDialog(
						L10n.string(SettingsStrings.deleteWinePrefixConfirmation),
						isPresented: $confirmsWinePrefixDeletion,
						titleVisibility: .visible
					) {
						Button(
							L10n.string(SettingsStrings.deleteWinePrefixAction), role: .destructive,
							action: model.deleteWinePrefix
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
					.disabled(!model.isInstalled || !model.canModifyGameFiles)
					.confirmationDialog(
						L10n.string(SettingsStrings.uninstallConfirmation),
						isPresented: $confirmsGameUninstall,
						titleVisibility: .visible
					) {
						Button(
							L10n.string(SettingsStrings.moveGameToTrash), role: .destructive,
							action: model.uninstallGame)
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
			return L10n.string(SettingsStrings.downloading(Int(progress.fraction * 100)))
		}
		if model.isDownloading { return L10n.string(SettingsStrings.preparingDownload) }
		if model.isInstalled { return L10n.string(SettingsStrings.installed) }
		return L10n.string(
			model.hasPartialDownload ? SettingsStrings.paused : SettingsStrings.notInstalled)
	}

	private var regionBinding: Binding<GameRegion> {
		Binding(get: { model.region }, set: { model.selectRegion($0) })
	}
}
