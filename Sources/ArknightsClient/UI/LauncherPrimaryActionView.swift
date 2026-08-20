// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct LauncherPrimaryActionView: View {
	var model: LauncherViewModel

	@ViewBuilder
	var body: some View {
		if model.isGameRunning {
			Button("Stop", systemImage: "stop.fill", action: model.stopGame)
				.adaptiveGlassCapsuleButton()
				.controlSize(.large)
				.disabled(!model.canStopGame)
				.help("Stop Arknights and its Windows runtime")
		} else if model.isDownloading {
			Button("Pause", systemImage: "pause.fill", action: model.cancelDownload)
				.adaptiveGlassCapsuleButton()
				.controlSize(.large)
				.help("Pause the download; it resumes from partial files later")
		} else if !model.isInstalled {
			Button(action: model.installOrUpdate) {
				Label(
					model.hasPartialDownload ? "Resume" : "Install",
					systemImage: model.hasPartialDownload ? "arrow.clockwise" : "arrow.down"
				)
				.foregroundStyle(model.accentTextColor)
			}
			.adaptiveGlassCapsuleButton(prominent: true)
			.controlSize(.large)
			.tint(model.accentColor)
			.disabled(!model.canInstall)
			.keyboardShortcut(.defaultAction)
			.help(
				model.hasPartialDownload
					? "Continue downloading from the partial files"
					: "Download and verify the official \(model.region.displayName) PC files"
			)
		} else if model.isGameUpdateAvailable {
			Button(action: model.installOrUpdate) {
				Label("Update", systemImage: "arrow.down")
					.foregroundStyle(model.accentTextColor)
			}
			.adaptiveGlassCapsuleButton(prominent: true)
			.controlSize(.large)
			.tint(model.accentColor)
			.disabled(!model.canInstall)
			.keyboardShortcut(.defaultAction)
			.help("Download the changed game files")
		} else {
			Button(action: model.launch) {
				Label("Play", systemImage: "play.fill")
					.foregroundStyle(model.accentTextColor)
			}
			.adaptiveGlassCapsuleButton(prominent: true)
			.controlSize(.large)
			.tint(model.accentColor)
			.disabled(!model.canLaunch)
			.keyboardShortcut(.defaultAction)
			.help("Start Arknights")
		}
	}
}
