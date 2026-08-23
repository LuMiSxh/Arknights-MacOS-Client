// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct LauncherPrimaryActionView: View {
	let installation: InstallationController
	let gameSession: GameSessionController
	let intelTranslation: IntelTranslationController
	let accentColor: Color
	let installOrUpdate: () -> Void
	let cancelDownload: () -> Void
	let launch: () -> Void
	let stopGame: () -> Void

	@ViewBuilder
	var body: some View {
		if gameSession.isGameActive {
			CapsuleActionButton(
				title: L10n.string(HomeStrings.actionStop),
				systemImage: "stop.fill", tone: .neutral,
				action: stopGame
			)
			.controlSize(.large)
			.disabled(!gameSession.canStopGame)
			.help(L10n.string(HomeStrings.actionStopHelp))
		} else if installation.isDownloading {
			CapsuleActionButton(
				title: L10n.string(HomeStrings.actionPause),
				systemImage: "pause.fill", tone: .neutral,
				action: cancelDownload
			)
			.controlSize(.large)
			.help(L10n.string(HomeStrings.actionPauseHelp))
		} else if !installation.isInstalled {
			CapsuleActionButton(
				title: L10n.string(
					installation.hasPartialDownload
						? HomeStrings.actionResume : HomeStrings.actionInstall
				),
				systemImage: installation.hasPartialDownload ? "arrow.clockwise" : "arrow.down",
				tone: .accent(accentColor),
				action: installOrUpdate
			)
			.controlSize(.large)
			.disabled(!installation.canInstall)
			.keyboardShortcut(.defaultAction)
			.help(
				installation.hasPartialDownload
					? L10n.string(HomeStrings.actionResumeHelp)
					: L10n.string(
						HomeStrings.actionInstallHelp(
							region: installation.region.localizedDisplayName)
					)
			)
		} else if installation.isGameUpdateAvailable {
			CapsuleActionButton(
				title: L10n.string(HomeStrings.actionUpdate),
				systemImage: "arrow.down", tone: .accent(accentColor),
				action: installOrUpdate
			)
			.controlSize(.large)
			.disabled(!installation.canInstall)
			.keyboardShortcut(.defaultAction)
			.help(L10n.string(HomeStrings.actionUpdateHelp))
		} else {
			CapsuleActionButton(
				title: L10n.string(HomeStrings.actionPlay),
				systemImage: "play.fill", tone: .accent(accentColor),
				action: launch
			)
			.controlSize(.large)
			.disabled(!gameSession.canLaunch)
			.keyboardShortcut(.defaultAction)
			.help(
				intelTranslation.statusDetail
					?? L10n.string(HomeStrings.actionPlayHelp)
			)
		}
	}
}
