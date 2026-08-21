// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct LauncherPrimaryActionView: View {
	var model: LauncherViewModel

	@ViewBuilder
	var body: some View {
		if model.isGameRunning {
			CapsuleActionButton(
				title: "Stop", systemImage: "stop.fill", tone: .neutral,
				action: model.stopGame
			)
			.controlSize(.large)
			.disabled(!model.canStopGame)
			.help("Stop Arknights and its Windows runtime")
		} else if model.isDownloading {
			CapsuleActionButton(
				title: "Pause", systemImage: "pause.fill", tone: .neutral,
				action: model.cancelDownload
			)
			.controlSize(.large)
			.help("Pause the download; it resumes from partial files later")
		} else if !model.isInstalled {
			CapsuleActionButton(
				title: model.hasPartialDownload ? "Resume" : "Install",
				systemImage: model.hasPartialDownload ? "arrow.clockwise" : "arrow.down",
				tone: .accent(model.accentColor),
				action: model.installOrUpdate
			)
			.controlSize(.large)
			.disabled(!model.canInstall)
			.keyboardShortcut(.defaultAction)
			.help(
				model.hasPartialDownload
					? "Continue downloading from the partial files"
					: "Download and verify the official \(model.region.displayName) PC files"
			)
		} else if model.isGameUpdateAvailable {
			CapsuleActionButton(
				title: "Update", systemImage: "arrow.down", tone: .accent(model.accentColor),
				action: model.installOrUpdate
			)
			.controlSize(.large)
			.disabled(!model.canInstall)
			.keyboardShortcut(.defaultAction)
			.help("Download the changed game files")
		} else {
			CapsuleActionButton(
				title: "Play", systemImage: "play.fill", tone: .accent(model.accentColor),
				action: model.launch
			)
			.controlSize(.large)
			.disabled(!model.canLaunch)
			.keyboardShortcut(.defaultAction)
			.help(model.playHelp)
		}
	}
}
