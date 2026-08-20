// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

struct OnboardingFinishView: View {
	let model: LauncherViewModel

	var body: some View {
		OnboardingPage(
			title: "Ready for deployment",
			subtitle:
				"Your launcher settings are saved. You can change every choice again from Settings.",
			accentColor: model.accentColor
		) {
			OnboardingPanel(title: gameStatusTitle, systemImage: gameStatusImage) {
				Text(gameStatusDetail)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)

				if model.isDownloading, let progress = model.progress {
					ProgressView(value: progress.fraction)
						.tint(model.accentColor)
				}

				if !model.isInstalled && !model.isDownloading && model.canInstall {
					Button(
						"Resume Download", systemImage: "arrow.clockwise",
						action: model.installOrUpdate)
				}
			}

			OnboardingPanel(title: "Community project", systemImage: "person.3") {
				Text(
					"Arknights Client is an unofficial community launcher. It is not affiliated with, endorsed by, or supported by Hypergryph or Yostar."
				)
				.fixedSize(horizontal: false, vertical: true)
				Text(
					"If the launcher, Wine runtime, or embedded browser misbehaves, please report it on GitHub with the generated diagnostics."
				)
				.font(.callout)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
				Button(
					"Report a Launcher Problem…", systemImage: "ladybug", action: reportProblem
				)
				.adaptiveGlassCapsuleButton()
				.tint(SettingsVisuals.controlTint)

				SettingsHairline()

				Text(
					"For account, payment, or game-service issues, contact Yostar support instead."
				)
				.font(.callout)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
				Button(
					"Contact Yostar Support…", systemImage: "arrow.up.right.square",
					action: contactYostar
				)
				.adaptiveGlassCapsuleButton()
				.tint(SettingsVisuals.controlTint)
			}
		}
	}

	private var gameStatusTitle: String {
		if model.isGameActive { return "Arknights is running" }
		if model.isDownloading { return "Installation continues" }
		if model.isInstalled { return "Arknights is ready" }
		return "Installation is paused"
	}

	private var gameStatusImage: String {
		if model.isGameActive { return "gamecontroller.fill" }
		if model.isDownloading { return "arrow.down.circle" }
		if model.isInstalled { return "checkmark.circle" }
		return "pause.circle"
	}

	private var gameStatusDetail: String {
		if model.isGameActive {
			return "Close the game with Command-Q before finishing setup."
		}
		if model.isDownloading {
			return
				"Finishing setup does not stop the download. The main launcher shows progress and enables Play when verification completes."
		}
		if model.isInstalled {
			return "Finish setup to return to the launcher and start playing."
		}
		return "Resume the download now or finish setup and continue later from the main launcher."
	}

	private func reportProblem() {
		NSWorkspace.shared.open(IssueReportURL.build())
	}

	private func contactYostar() {
		NSWorkspace.shared.open(SupportLinks.yostarContact)
	}
}
