// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct LauncherPrimaryActionView: View {
	var model: LauncherViewModel

	@ViewBuilder
	var body: some View {
		if model.isGameRunning {
			CapsuleActionButton(
				title: L10n.string(HomeStrings.actionStop),
				systemImage: "stop.fill", tone: .neutral,
				action: model.stopGame
			)
			.controlSize(.large)
			.disabled(!model.canStopGame)
			.help(L10n.string(HomeStrings.actionStopHelp))
		} else if model.isDownloading {
			CapsuleActionButton(
				title: L10n.string(HomeStrings.actionPause),
				systemImage: "pause.fill", tone: .neutral,
				action: model.cancelDownload
			)
			.controlSize(.large)
			.help(L10n.string(HomeStrings.actionPauseHelp))
		} else if !model.isInstalled {
			CapsuleActionButton(
				title: L10n.string(
					model.hasPartialDownload ? HomeStrings.actionResume : HomeStrings.actionInstall
				),
				systemImage: model.hasPartialDownload ? "arrow.clockwise" : "arrow.down",
				tone: .accent(model.accentColor),
				action: model.installOrUpdate
			)
			.controlSize(.large)
			.disabled(!model.canInstall)
			.keyboardShortcut(.defaultAction)
			.help(
				model.hasPartialDownload
					? L10n.string(HomeStrings.actionResumeHelp)
					: L10n.string(
						HomeStrings.actionInstallHelp(region: model.region.localizedDisplayName)
					)
			)
		} else if model.isGameUpdateAvailable {
			CapsuleActionButton(
				title: L10n.string(HomeStrings.actionUpdate),
				systemImage: "arrow.down", tone: .accent(model.accentColor),
				action: model.installOrUpdate
			)
			.controlSize(.large)
			.disabled(!model.canInstall)
			.keyboardShortcut(.defaultAction)
			.help(L10n.string(HomeStrings.actionUpdateHelp))
		} else {
			CapsuleActionButton(
				title: L10n.string(HomeStrings.actionPlay),
				systemImage: "play.fill", tone: .accent(model.accentColor),
				action: model.launch
			)
			.controlSize(.large)
			.disabled(!model.canLaunch)
			.keyboardShortcut(.defaultAction)
			.help(
				model.intelTranslationStatusDetail
					?? L10n.string(HomeStrings.actionPlayHelp)
			)
		}
	}
}
