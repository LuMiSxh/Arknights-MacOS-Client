// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsGameRuntime
import SwiftUI

struct InstallationSettingsPage: View {
	@Environment(\.launcherTheme) var theme

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
			if let reason = lifecycle.activity.lockReason {
				SettingsLockBanner(reason: reason)
			}

			SettingsPanel(title: "Server") {
				SettingsActionRow(
					title: "Server",
					detail: "Each server keeps its own game files and updates."
				) {
					GlassMenuPicker(
						selection: regionBinding,
						options: GameRegion.allCases.map {
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
					detail: gameFilesDetail
				) {
					ExternalLinkButton(
						title: "Show in Finder",
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
				if !installation.isInstalled {
					SettingsFootnote("Install the game to show its files in Finder.")
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
				SettingsActionRow(
					title: "Verify Files",
					detail: "Check the game files against the manifest. Nothing is changed."
				) {
					CapsuleActionButton(
						title: "Verify Files",
						systemImage: "checkmark.shield",
						tone: .neutral, presentation: .compact,
						action: actions.verifyGameFiles
					)
					.disabled(!installation.isInstalled || !installation.canInstall)
				}
				if installation.isInstalled, let verification = installation.fileVerification {
					SettingsActionRow(title: verificationSummary(verification)) {
						if !verification.damagedPaths.isEmpty {
							CapsuleActionButton(
								title: "Repair",
								systemImage: "wrench.and.screwdriver",
								tone: .neutral, presentation: .compact,
								action: actions.repairGame
							)
							.disabled(!installation.canInstall)
						}
					}
				}
				if !installation.isInstalled {
					SettingsFootnote("Install the game before you verify or repair it.")
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
				if !installation.isInstalled && !installation.hasPartialDownload {
					SettingsFootnote("Install the game before you uninstall it.")
				}
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

	/// The install folder, then the static state. Live progress stays in the operation strip.
	private var gameFilesDetail: String {
		let path = (installation.installDirectory.path(percentEncoded: false) as NSString)
			.abbreviatingWithTildeInPath
		return "\(path) · \(gameFilesStatus)"
	}

	private func verificationSummary(_ verification: GameFileVerification) -> String {
		switch verification.damagedPaths.count {
		case 0: "All files are intact."
		case 1: "1 file is damaged or missing."
		case let count: "\(count) files are damaged or missing."
		}
	}

	private var gameFilesStatus: String {
		if case .installing(_, .verifying) = lifecycle.activity { return "Verifying files…" }
		if installation.isDownloading { return "Downloading" }
		return LauncherDownloadProgressPresentation.gameStatus(
			isDownloading: false,
			progress: nil,
			isInstalled: installation.isInstalled,
			hasPartialDownload: installation.hasPartialDownload
		)
	}
}
