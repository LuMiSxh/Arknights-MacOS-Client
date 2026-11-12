// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsGameRuntime
import SwiftUI

struct LauncherPrimaryActionView: View {
	let presentation: LauncherPrimaryActionPresentation
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		CapsuleActionButton(
			title: presentation.title,
			systemImage: presentation.systemImage,
			tone: presentation.tone,
			labelMotion: .primary,
			action: presentation.action
		)
		.controlSize(.large)
		.accentHalo(
			// The halo is the only ambient effect and shows only for an enabled Play.
			isActive: presentation.kind == .play && !presentation.isDisabled,
			in: Capsule()
		)
		.disabled(presentation.isDisabled)
		.animation(
			LauncherMotion.animation(.morph, reduceMotion: reduceMotion),
			value: presentation.kind
		)
		.help(presentation.help)
		.accessibilityHint(presentation.help)
	}
}

/// The Home primary action's state machine: the kind and every display value it drives.
struct LauncherPrimaryActionPresentation {
	enum Kind: CaseIterable {
		case stop
		case pause
		case install
		case update
		case runtime
		case play
	}

	let kind: Kind
	let installOrUpdate: () -> Void
	let cancelDownload: () -> Void
	let installRuntime: () -> Void
	let launch: () -> Void
	let stopGame: () -> Void

	private let hasPartialDownload: Bool
	private let regionDisplayName: String
	private let intelTranslationDetail: String?
	private let canStopGame: Bool
	private let canInstall: Bool
	private let runtimeIsInstalling: Bool
	private let runtimeState: RuntimeLaneState
	private let isIdle: Bool
	private let canLaunch: Bool

	init(
		installation: InstallationController,
		gameSession: GameSessionController,
		intelTranslation: IntelTranslationController,
		runtimeSelection: RuntimeSelectionController,
		lifecycle: LauncherLifecycleStore,
		installOrUpdate: @escaping () -> Void,
		cancelDownload: @escaping () -> Void,
		installRuntime: @escaping () -> Void,
		launch: @escaping () -> Void,
		stopGame: @escaping () -> Void
	) {
		self.kind = Self.kind(
			gameSession: gameSession,
			installation: installation,
			runtimeSelection: runtimeSelection
		)
		self.installOrUpdate = installOrUpdate
		self.cancelDownload = cancelDownload
		self.installRuntime = installRuntime
		self.launch = launch
		self.stopGame = stopGame
		self.hasPartialDownload = installation.hasPartialDownload
		self.regionDisplayName = installation.region.displayName
		self.intelTranslationDetail = intelTranslation.statusDetail
		self.canStopGame = gameSession.canStopGame
		self.canInstall = installation.canInstall
		self.runtimeIsInstalling = runtimeSelection.isInstalling
		self.runtimeState = runtimeSelection.selectedLaneState
		self.isIdle = lifecycle.activity == .idle
		self.canLaunch = gameSession.canLaunch
	}

	var action: () -> Void {
		switch kind {
		case .stop: stopGame
		case .pause: cancelDownload
		case .install, .update: installOrUpdate
		case .runtime: installRuntime
		case .play: launch
		}
	}

	var title: String {
		switch kind {
		case .stop: "Stop"
		case .pause: "Pause"
		case .install: hasPartialDownload ? "Resume" : "Install"
		case .update: "Update"
		case .runtime:
			switch runtimeState {
			case .outdated: "Update Runtime"
			case .notInstalled, .current: "Set Up Runtime"
			}
		case .play: "Play"
		}
	}

	var systemImage: String {
		switch kind {
		case .stop: "stop.fill"
		case .pause: "pause.fill"
		case .install: hasPartialDownload ? "arrow.clockwise" : "arrow.down"
		case .update: "arrow.down"
		case .runtime:
			switch runtimeState {
			case .outdated: "arrow.down"
			case .notInstalled, .current: "shippingbox"
			}
		case .play: "play.fill"
		}
	}

	var tone: CapsuleActionTone {
		switch kind {
		case .stop, .pause: .neutral
		case .install, .update, .runtime, .play: .accent
		}
	}

	var isDisabled: Bool {
		switch kind {
		case .stop: !canStopGame
		case .pause: false
		case .install, .update: !canInstall
		case .runtime: runtimeIsInstalling || !isIdle
		case .play: !canLaunch
		}
	}

	var help: String {
		switch kind {
		case .stop: return "Stop Arknights"
		case .pause: return "Pause the download. You can resume it later."
		case .install:
			if hasPartialDownload {
				return "Resume the download"
			}
			return "Download and verify the official \(regionDisplayName) PC files"
		case .update: return "Download the changed game files"
		case .runtime:
			switch runtimeState {
			case .outdated:
				return "Download the runtime update this launcher release requires."
			case .notInstalled, .current:
				return "Download the runtime for this Mac. Arknights needs it to start."
			}
		case .play: return intelTranslationDetail ?? "Start Arknights"
		}
	}

	private static func kind(
		gameSession: GameSessionController,
		installation: InstallationController,
		runtimeSelection: RuntimeSelectionController
	) -> Kind {
		if gameSession.isGameActive { return .stop }
		if installation.isDownloading { return .pause }
		if installation.hasPartialDownload { return .install }
		if !installation.isInstalled { return .install }
		if installation.isGameUpdateAvailable { return .update }
		if !runtimeSelection.isSelectedLaneInstalled { return .runtime }
		return .play
	}
}
