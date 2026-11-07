// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsGameRuntime
import SwiftUI

struct LauncherPrimaryActionView: View {
	let installation: InstallationController
	let gameSession: GameSessionController
	let intelTranslation: IntelTranslationController
	let runtimeSelection: RuntimeSelectionController
	let lifecycle: LauncherLifecycleStore
	let installOrUpdate: () -> Void
	let cancelDownload: () -> Void
	let installRuntime: () -> Void
	let launch: () -> Void
	let stopGame: () -> Void
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		CapsuleActionButton(
			title: actionTitle,
			systemImage: actionImage,
			tone: actionTone,
			labelMotion: .primary,
			action: action
		)
		.controlSize(.large)
		.accentHalo(
			// The halo is the only ambient effect and shows only for an enabled Play.
			isActive: actionKind == .play && !actionIsDisabled,
			in: Capsule()
		)
		.disabled(actionIsDisabled)
		.animation(
			LauncherMotion.animation(.morph, reduceMotion: reduceMotion),
			value: actionKind
		)
		.help(actionHelp)
		.accessibilityHint(actionHelp)
	}

	private var action: () -> Void {
		switch actionKind {
		case .stop: stopGame
		case .pause: cancelDownload
		case .install, .update: installOrUpdate
		case .runtime: installRuntime
		case .play: launch
		}
	}

	private var actionTitle: String {
		switch actionKind {
		case .stop: "Stop"
		case .pause: "Pause"
		case .install:

			installation.hasPartialDownload
				? "Resume" : "Install"

		case .update: "Update"
		case .runtime: "Set Up Runtime"
		case .play: "Play"
		}
	}

	private var actionImage: String {
		switch actionKind {
		case .stop: "stop.fill"
		case .pause: "pause.fill"
		case .install: installation.hasPartialDownload ? "arrow.clockwise" : "arrow.down"
		case .update: "arrow.down"
		case .runtime: "shippingbox"
		case .play: "play.fill"
		}
	}

	private var actionTone: CapsuleActionTone {
		switch actionKind {
		case .stop, .pause: .neutral
		case .install, .update, .runtime, .play: .accent
		}
	}

	private var actionIsDisabled: Bool {
		switch actionKind {
		case .stop: !gameSession.canStopGame
		case .pause: false
		case .install, .update: !installation.canInstall
		case .runtime:
			runtimeSelection.isInstalling || lifecycle.activity != .idle
		case .play: !gameSession.canLaunch || runtimeSelection.requiresRelaunch
		}
	}

	private var actionHelp: String {
		switch actionKind {
		case .stop: return "Stop Arknights"
		case .pause: return "Pause the download. You can resume it later."
		case .install:
			if installation.hasPartialDownload {
				return "Resume the download"
			}
			return
				"Download and verify the official \(installation.region.displayName) PC files"

		case .update: return "Download the changed game files"
		case .runtime:
			return "Download the runtime for this Mac. Arknights needs it to start."
		case .play: return intelTranslation.statusDetail ?? "Start Arknights"
		}
	}

	private var actionKind: ActionKind {
		if gameSession.isGameActive { return .stop }
		if installation.isDownloading { return .pause }
		if installation.hasPartialDownload { return .install }
		if !installation.isInstalled { return .install }
		if installation.isGameUpdateAvailable { return .update }
		if !runtimeSelection.isSelectedLaneInstalled { return .runtime }
		return .play
	}

	private typealias ActionKind = LauncherPrimaryActionPresentation.Kind
}

nonisolated enum LauncherPrimaryActionPresentation {
	nonisolated enum Kind: CaseIterable {
		case stop
		case pause
		case install
		case update
		case runtime
		case play
	}
}
