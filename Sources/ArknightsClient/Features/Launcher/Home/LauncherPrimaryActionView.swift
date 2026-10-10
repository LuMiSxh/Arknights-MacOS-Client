// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
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
			tint: accentColor,
			isActive: LauncherPrimaryActionPresentation.showsHalo(
				kind: actionKind, isDisabled: actionIsDisabled),
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
		case .play: launch
		}
	}

	private var actionTitle: String {
		switch actionKind {
		case .stop: HomeStrings.actionStop
		case .pause: HomeStrings.actionPause
		case .install:

			installation.hasPartialDownload
				? HomeStrings.actionResume : HomeStrings.actionInstall

		case .update: HomeStrings.actionUpdate
		case .play: HomeStrings.actionPlay
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
		case .stop: return HomeStrings.actionStopHelp
		case .pause: return HomeStrings.actionPauseHelp
		case .install:
			if installation.hasPartialDownload {
				return HomeStrings.actionResumeHelp
			}
			return
				HomeStrings.actionInstallHelp(region: installation.region.displayName)

		case .update: return HomeStrings.actionUpdateHelp
		case .play: return intelTranslation.statusDetail ?? HomeStrings.actionPlayHelp
		}
	}

	private var actionKind: ActionKind {
		if gameSession.isGameActive { return .stop }
		if installation.isDownloading { return .pause }
		if installation.hasPartialDownload { return .install }
		if !installation.isInstalled { return .install }
		if installation.isGameUpdateAvailable { return .update }
		return .play
	}

	private typealias ActionKind = LauncherPrimaryActionPresentation.Kind
}

enum LauncherPrimaryActionPresentation {
	enum Kind: CaseIterable {
		case stop
		case pause
		case install
		case update
		case play
	}

	/// The halo is the only ambient effect and shows only for an enabled Play.
	static func showsHalo(kind: Kind, isDisabled: Bool) -> Bool {
		kind == .play && !isDisabled
	}
}
