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

	var body: some View {
		CapsuleActionButton(
			title: actionTitle,
			systemImage: actionImage,
			tone: actionTone,
			action: action
		)
		.controlSize(.large)
		.disabled(actionIsDisabled)
		.help(actionHelp)
		.accessibilityHint(actionHelp)
	}

	private var action: () -> Void {
		switch actionKind {
		case .stop: stopGame
		case .pause: cancelDownload
		case .install, .update: installOrUpdate
		case .play: launch
		}
	}

	private var actionTitle: String {
		switch actionKind {
		case .stop: L10n.string(HomeStrings.actionStop)
		case .pause: L10n.string(HomeStrings.actionPause)
		case .install:
			L10n.string(
				installation.hasPartialDownload
					? HomeStrings.actionResume : HomeStrings.actionInstall
			)
		case .update: L10n.string(HomeStrings.actionUpdate)
		case .play: L10n.string(HomeStrings.actionPlay)
		}
	}

	private var actionImage: String {
		switch actionKind {
		case .stop: "stop.fill"
		case .pause: "pause.fill"
		case .install: installation.hasPartialDownload ? "arrow.clockwise" : "arrow.down"
		case .update: "arrow.down"
		case .play: "play.fill"
		}
	}

	private var actionTone: CapsuleActionTone {
		switch actionKind {
		case .stop, .pause: .neutral
		case .install, .update, .play: .accent(accentColor)
		}
	}

	private var actionIsDisabled: Bool {
		switch actionKind {
		case .stop: !gameSession.canStopGame
		case .pause: false
		case .install, .update: !installation.canInstall
		case .play: !gameSession.canLaunch
		}
	}

	private var actionHelp: String {
		switch actionKind {
		case .stop: return L10n.string(HomeStrings.actionStopHelp)
		case .pause: return L10n.string(HomeStrings.actionPauseHelp)
		case .install:
			if installation.hasPartialDownload {
				return L10n.string(HomeStrings.actionResumeHelp)
			}
			return L10n.string(
				HomeStrings.actionInstallHelp(region: installation.region.localizedDisplayName)
			)
		case .update: return L10n.string(HomeStrings.actionUpdateHelp)
		case .play: return intelTranslation.statusDetail ?? L10n.string(HomeStrings.actionPlayHelp)
		}
	}

	private var actionKind: ActionKind {
		if gameSession.isGameActive { return .stop }
		if installation.isDownloading { return .pause }
		if !installation.isInstalled { return .install }
		if installation.isGameUpdateAvailable { return .update }
		return .play
	}

	private enum ActionKind {
		case stop
		case pause
		case install
		case update
		case play
	}
}
