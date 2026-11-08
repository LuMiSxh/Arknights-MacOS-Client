// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsGameInstallation
import ArknightsGameRuntime
import SwiftUI

struct HelpSettingsPage: View {
	let region: GameRegion
	let actions: any LauncherDiagnosticsActions
	let maintenance: any LauncherSettingsActions
	let openProblemReport: () -> Void
	let installation: InstallationController
	let gameSession: GameSessionController
	let lifecycle: LauncherLifecycleStore
	let restartOnboarding: () -> Void
	let revealApplicationSupport: () -> Void
	@State private var confirmation: InstallationConfirmation?

	var body: some View {
		SettingsPage(
			title: "Help",
			subtitle: "Report problems and find solutions"
		) {
			SettingsPanel(title: "Report") {
				SettingsActionRow(
					title: "Problems on this Mac",
					detail:
						"Report problems with the launcher, the game start, graphics, sound, or the sign-in window. The report adds your launcher version, Mac chip, memory, and macOS version."
				) {
					CapsuleActionButton(
						title: "Report a Problem…", systemImage: "ladybug",
						tone: .neutral, presentation: .compact,
						action: reportLauncherProblem
					)
				}

				SettingsHairline()

				SettingsActionRow(
					title: "Diagnostics",
					detail:
						"Save the launcher and game logs with your display settings. Logs are redacted for your home folder and URL queries. Nothing is uploaded. Review the file before you share it."
				) {
					CapsuleActionButton(
						title: "Save…", systemImage: "square.and.arrow.down",
						tone: .neutral, presentation: .compact
					) {
						Task { await actions.saveDiagnostics() }
					}
					.disabled(actions.isSavingDiagnostics)
				}
			}

			SettingsPanel(title: "Get help") {
				SettingsActionRow(
					title: "Troubleshooting guide",
					detail:
						"Read solutions for common problems with installation, the game start, and display."
				) {
					CapsuleActionButton(
						title: "Open Guide", systemImage: "arrow.up.right.square",
						tone: .neutral, presentation: .compact
					) {
						NSWorkspace.shared.open(SupportLinks.troubleshootingGuide)
					}
				}

				SettingsHairline()

				SettingsActionRow(
					title: "Account and payment",
					detail:
						"Contact \(region.publisherName) for account, payment, or game-event problems."
				) {
					CapsuleActionButton(
						title: "Contact \(region.publisherName)…",
						systemImage: "arrow.up.right.square",
						tone: .neutral, presentation: .compact,
						action: contactPublisher
					)
				}

				SettingsHairline()

				SettingsActionRow(
					title: "Contact the developer",
					detail:
						"Send a private message about testing, feedback, or a problem you do not want to report in public."
				) {
					CapsuleActionButton(
						title: "Contact…", systemImage: "envelope",
						tone: .neutral, presentation: .compact
					) {
						NSWorkspace.shared.open(SupportLinks.developerContact)
					}
				}
			}
			SettingsPanel(title: "Troubleshooting") {
				SettingsActionRow(
					title: "Setup assistant",
					detail: "Go through the first-run questions again."
				) {
					CapsuleActionButton(
						title: "Run Setup Again…", systemImage: "wand.and.stars",
						tone: .neutral, presentation: .compact,
						action: restartOnboarding
					)
					.disabled(gameSession.isGameActive)
				}
				SettingsHairline()
				SettingsActionRow(
					title: "App Data Folder",
					detail: "Settings, logs, runtimes, and game environments."
				) {
					CapsuleActionButton(
						title: "Show in Finder", systemImage: "folder",
						tone: .neutral, presentation: .compact,
						action: revealApplicationSupport
					)
				}
				SettingsHairline()
				InstallationDestructiveRow(
					title: "Rebuild game environment",
					detail: InstallationConfirmation.rebuildDetail,
					help:
						"Recreates the game environment. Your game files stay installed.",
					buttonTitle: "Rebuild…",
					systemImage: "arrow.triangle.2.circlepath",
					isDisabled: !installation.canModifyGameFiles,
					confirming: .rebuildEnvironment,
					confirmation: $confirmation
				)
				SettingsHairline()
				InstallationDestructiveRow(
					title: "Delete game environment",
					detail: "Signs you out of every sign-in provider. Game files stay.",
					help:
						"Deletes the game environment shared by this publisher’s servers.",
					buttonTitle: "Delete Environment…",
					systemImage: "trash",
					isDisabled: !installation.canModifyGameFiles,
					confirming: .deleteEnvironment,
					confirmation: $confirmation
				)
				SettingsHairline()
				InstallationDestructiveRow(
					title: "Reset launcher settings",
					detail: InstallationConfirmation.settingsResetDetail,
					buttonTitle: "Reset All Settings…",
					systemImage: "arrow.counterclockwise",
					isDisabled: gameSession.isGameActive || lifecycle.activity != .idle,
					confirming: .resetSettings,
					confirmation: $confirmation
				)
			}
		}
		.installationConfirmation($confirmation, gameSession: gameSession, actions: maintenance)
	}

	private func reportLauncherProblem() {
		openProblemReport()
	}

	private func contactPublisher() {
		NSWorkspace.shared.open(SupportLinks.contact(for: region))
	}
}
