// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import SwiftUI

struct HelpSettingsPage: View {
	package let region: GameRegion
	package let runtimeName: String?
	package let accentColor: Color
	let actions: any LauncherActions

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
			}
		}
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
