// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

struct OnboardingFinishView: View {
	let installation: InstallationController
	let lifecycle: LauncherLifecycleStore
	let accentColor: Color
	let install: () -> Void

	var body: some View {
		OnboardingPage(
			title: "Setup complete",
			subtitle: "Your choices are saved. You can change any of them in Settings",
			accentColor: accentColor
		) {
			SettingsPanel(title: "Server", systemImage: "globe") {
				OnboardingStatusRow(
					title: installation.region.displayName,
					detail: "Each server has its own game files and accounts.",
					systemImage: "globe"
				) {}
			}

			SettingsPanel(title: "Game files", systemImage: "externaldrive") {
				OnboardingFinishGameStatus(
					installation: installation,
					title: gameStatusTitle,
					systemImage: gameStatusImage,
					detail: gameStatusDetail,
					accentColor: accentColor,
					install: install
				)
			}

			SettingsPanel(title: "Get help", systemImage: "lifepreserver") {
				OnboardingStatusRow(
					title: "Troubleshooting guide",
					detail:
						"Find solutions for common problems. Choose Troubleshooting Guide in the Help menu, or open Settings → Help.",
					systemImage: "book"
				) {
					CapsuleActionButton(
						title: "Open Guide", systemImage: "arrow.up.right.square",
						tone: .neutral, action: openTroubleshooting
					)
				}
				OnboardingStatusRow(
					title: "Problems on this Mac",
					detail:
						"Choose Report a Problem… in the Help menu, or open Settings → Help → Report.",
					systemImage: "ladybug"
				) {
					CapsuleActionButton(
						title: "Report a Problem…", systemImage: "ladybug",
						tone: .neutral, action: reportProblem
					)
				}
				OnboardingStatusRow(
					title: "Diagnostics",
					detail:
						"Save the launcher and game logs for a report. Choose Save Diagnostics… in the Help menu.",
					systemImage: "square.and.arrow.down"
				) {}
				OnboardingStatusRow(
					title: "Account and payment",
					detail:
						"For account, payment, or game-service issues, contact \(installation.region.publisherName) support instead.",
					systemImage: "person.crop.circle"
				) {
					CapsuleActionButton(
						title: "Contact \(installation.region.publisherName) Support…",
						systemImage: "arrow.up.right.square",
						tone: .neutral, action: contactPublisher
					)
				}
			}

			SettingsPanel(title: "Community project", systemImage: "person.3") {
				Text(
					"Arknights Client is an unofficial community launcher. It is not affiliated with, endorsed by, or supported by Hypergryph or Yostar."
				)
				.fixedSize(horizontal: false, vertical: true)
			}
		}
	}

	private var gameStatusTitle: String {
		if lifecycle.activity.isGameActive { return "Arknights is running" }
		if installation.isDownloading { return "The download continues" }
		if installation.isInstalled { return "Arknights is ready" }
		return "The download is paused"
	}

	private var gameStatusImage: String {
		if lifecycle.activity.isGameActive { return "gamecontroller.fill" }
		if installation.isDownloading { return "arrow.down.circle" }
		if installation.isInstalled { return "checkmark.circle" }
		return "pause.circle"
	}

	private var gameStatusDetail: String {
		if lifecycle.activity.isGameActive {
			return "Close the game with Command-Q before finishing setup."
		}
		if installation.isDownloading {
			return
				"Finishing setup does not stop the download. The launcher shows its progress and unlocks Play when it is done."
		}
		if installation.isInstalled {
			return "Finish setup to return to the launcher and start playing."
		}
		return "Resume the download now, or finish setup and continue later from the launcher."
	}

	private func reportProblem() {
		NSWorkspace.shared.open(
			IssueReportURL.build(
				runtimeName: lifecycle.state.readiness.runtimeName, source: .onboarding))
	}

	private func openTroubleshooting() {
		NSWorkspace.shared.open(SupportLinks.troubleshootingGuide)
	}

	private func contactPublisher() {
		NSWorkspace.shared.open(SupportLinks.contact(for: installation.region))
	}
}
