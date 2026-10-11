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
			title: "Ready for deployment",
			subtitle: "Your choices are saved. You can change any of them in Settings.",
			accentColor: accentColor
		) {
			SettingsPanel(title: gameStatusTitle, systemImage: gameStatusImage) {
				Text(gameStatusDetail)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)

				if installation.isDownloading, let progress = installation.progress {
					ProgressView(value: progress.fraction)
						.tint(accentColor)
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

			SettingsPanel(
				title: "Community project", systemImage: "person.3"
			) {
				Text(
					"Arknights Client is an unofficial community launcher. It is not affiliated with, endorsed by, or supported by Hypergryph or Yostar."
				)
				.fixedSize(horizontal: false, vertical: true)
				Text(
					"If the launcher, the game start, or the sign-in window misbehaves, please report it on GitHub. The report fills in the technical details for you."
				)
				.font(.callout)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
				CapsuleActionButton(
					title: "Report a Launcher Problem…", systemImage: "ladybug",
					tone: .accent(accentColor), action: reportProblem
				)

				SettingsHairline()

				Text(OnboardingStrings.communitySupport(region: installation.region))
					.font(.callout)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
				CapsuleActionButton(
					title:
						OnboardingStrings.contactSupport(region: installation.region),
					systemImage: "arrow.up.right.square",
					tone: .accent(accentColor),
					action: contactPublisher
				)
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
			IssueReportURL.build(runtimeName: lifecycle.state.readiness.runtimeName))
	}

	private func contactPublisher() {
		NSWorkspace.shared.open(SupportLinks.contact(for: installation.region))
	}
}
