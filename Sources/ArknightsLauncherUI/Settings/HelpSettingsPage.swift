// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsGameInstallation
import ArknightsGameRuntime
import SwiftUI

struct HelpSettingsPage: View {
	package let region: GameRegion
	package let runtimeName: String?
	package let accentColor: Color
	let actions: any LauncherActions
	package let installation: InstallationController
	let gameSession: GameSessionController
	package let lifecycle: LauncherLifecycleStore
	let restartOnboarding: () -> Void
	@State private var confirmation: InstallationConfirmation?

	var body: some View {
		SettingsPage(
			title: "Help",
			subtitle: "Report problems and find solutions",
			accentColor: accentColor
		) {
			SettingsPanel(title: "Report", systemImage: "ladybug") {
				SettingsActionRow(
					title: "Problems on This Mac",
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

			SettingsPanel(title: "Get Help", systemImage: "lifepreserver") {
				SettingsActionRow(
					title: "Troubleshooting Guide",
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
					title: "Account and Payment",
					detail:
						"Contact \(publisherName) for account, payment, or game-event problems."
				) {
					CapsuleActionButton(
						title: "Contact \(publisherName)…",
						systemImage: "arrow.up.right.square",
						tone: .neutral, presentation: .compact,
						action: contactPublisher
					)
				}

				SettingsHairline()

				SettingsActionRow(
					title: "Contact the Developer",
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
			SettingsPanel(title: "Troubleshooting", systemImage: "wrench.and.screwdriver") {
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
				SettingsHairline()
				InstallationDestructiveRow(
					title: "Rebuild game environment",
					detail: InstallationConfirmation.rebuildDetail,
					help:
						"Recreates the Wine prefix with its graphics layer and registry overrides.",
					buttonTitle: "Rebuild…",
					systemImage: "arrow.triangle.2.circlepath",
					isDisabled: !installation.canModifyGameFiles,
					confirming: .rebuildEnvironment,
					confirmation: $confirmation
				)
				SettingsHairline()
				InstallationDestructiveRow(
					title: "Delete game environment",
					detail: "Signs you out of Yostar, Google, Apple and Facebook. Game files stay.",
					help: "Deletes the Wine prefix folder shared by this publisher's servers.",
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
		.installationConfirmation($confirmation, gameSession: gameSession, actions: actions)
	}

	private func reportLauncherProblem() {
		NSWorkspace.shared.open(IssueReportURL.build(runtimeName: runtimeName, source: .settings))
	}

	private func contactPublisher() {
		NSWorkspace.shared.open(SupportLinks.contact(for: region))
	}

	private var publisherName: String {
		switch region.publisher {
		case .gryphline: "Gryphline"
		case .hypergryph: "Hypergryph"
		default: "Yostar"
		}
	}
}
