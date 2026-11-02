// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

struct OnboardingFinishView: View {
	let installation: InstallationController
	let lifecycle: LauncherLifecycleStore
	@Environment(\.launcherTheme) private var theme
	let accentColor: Color
	let install: () -> Void

	var body: some View {
		OnboardingPage(
			title: "Setup complete",
			subtitle: "Your choices are saved. You can change any of them in Settings",
			accentColor: accentColor
		) {
			SettingsPanel(title: gameStatusTitle, systemImage: gameStatusImage) {
				VStack(alignment: .leading, spacing: 12) {
					Text(gameStatusDetail)
						.foregroundStyle(theme.textSecondary)
						.fixedSize(horizontal: false, vertical: true)

					if installation.isDownloading, let progress = installation.progress {
						ProgressView(value: progress.fraction)
							.tint(theme.accentFill)
					}

					if !installation.isInstalled && !installation.isDownloading
						&& installation.canInstall
					{
						CapsuleActionButton(
							title: "Resume Download",
							systemImage: "arrow.clockwise",
							tone: .accent(accentColor),
							action: install
						)
					}
				}
			}

			SettingsPanel(
				title: "Community project", systemImage: "person.3"
			) {
				VStack(alignment: .leading, spacing: 12) {
					Text(
						"Arknights Client is an unofficial community launcher. It is not affiliated with, endorsed by, or supported by Hypergryph or Yostar."
					)
					.fixedSize(horizontal: false, vertical: true)
					Text(
						"If the launcher, the game start, or the sign-in window misbehaves, please report it on GitHub. The report fills in the technical details for you."
					)
					.font(.callout)
					.foregroundStyle(theme.textSecondary)
					.fixedSize(horizontal: false, vertical: true)
					CapsuleActionButton(
						title: "Report a Problem…", systemImage: "ladybug",
						tone: .neutral, action: reportProblem
					)
				}

				VStack(alignment: .leading, spacing: 12) {
					Text(
						"For account, payment, or game-service issues, contact \(installation.region.publisherName) support instead."
					)
					.font(.callout)
					.foregroundStyle(theme.textSecondary)
					.fixedSize(horizontal: false, vertical: true)
					CapsuleActionButton(
						title: "Contact \(installation.region.publisherName) Support…",
						systemImage: "arrow.up.right.square",
						tone: .neutral,
						action: contactPublisher
					)
				}
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

	private func contactPublisher() {
		NSWorkspace.shared.open(SupportLinks.contact(for: installation.region))
	}
}
