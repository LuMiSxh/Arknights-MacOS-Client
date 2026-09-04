// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct LauncherHUDView: View {
	let lifecycle: LauncherLifecycleStore
	let settings: LauncherPreferencesController
	let installation: InstallationController
	let gameSession: GameSessionController
	let intelTranslation: IntelTranslationController
	let communication: LauncherCommunicationController
	let canSwitchRegion: Bool
	let accentColor: Color
	let hudTintColor: Color
	let musicController: BackgroundMusicController
	let openLauncherUpdate: () -> Void
	let checkGameUpdates: () -> Void
	let selectRegion: (GameRegion) -> Void
	let installOrUpdate: () -> Void
	let cancelDownload: () -> Void
	let launch: () -> Void
	let stopGame: () -> Void
	let requestRosettaInstallation: () -> Void
	let retryIntelTranslationCheck: () -> Void
	let showFailureDetails: () -> Void
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		VStack(spacing: 10) {
			hudPillRow
			controlBar
		}
		.padding(20)
	}

	private var controlBar: some View {
		HStack(spacing: 16) {
			LauncherActivityStatusView(
				lifecycle: lifecycle,
				installation: installation,
				intelTranslation: intelTranslation,
				accentColor: accentColor,
				requestRosettaInstallation: requestRosettaInstallation,
				retryIntelTranslationCheck: retryIntelTranslationCheck
			)
			.id(installation.isDownloading ? "download-progress" : "launcher-status")
			.transition(.opacity)
			.frame(maxWidth: .infinity, alignment: .leading)

			HStack(spacing: 8) {
				if communication.shouldShowLauncherUpdateButton {
					CapsuleActionButton(
						title: L10n.string(HomeStrings.launcherUpdate),
						systemImage: "arrow.down.app",
						tone: .accent(accentColor),
						action: openLauncherUpdate
					)
					.disabled(!communication.canOpenLauncherUpdate)
					.transition(.opacity)
					.help(L10n.string(HomeStrings.launcherUpdateHelp))
				}

				if lifecycle.failure?.blocksGameLaunch == true {
					CapsuleActionButton(
						title: L10n.string(HomeStrings.recoveryDetails),
						systemImage: "info.circle",
						tone: .accent(accentColor),
						action: showFailureDetails
					)
					.controlSize(.large)
					.transition(primaryActionTransition)
				}

				LauncherPrimaryActionView(
					installation: installation,
					gameSession: gameSession,
					intelTranslation: intelTranslation,
					accentColor: accentColor,
					installOrUpdate: installOrUpdate,
					cancelDownload: cancelDownload,
					launch: launch,
					stopGame: stopGame
				)
				.disabled(lifecycle.failure?.blocksGameLaunch == true)
				.transition(primaryActionTransition)
			}
		}
		.padding(16)
		.adaptiveGlassEffect(tint: hudTintColor, in: Capsule())
		.animation(stateAnimation, value: installation.isDownloading)
		.animation(stateAnimation, value: primaryActionIdentity)
		.animation(stateAnimation, value: communication.shouldShowLauncherUpdateButton)
		.animation(stateAnimation, value: lifecycle.failure?.id)
	}

	/// Only takes up the 10pt of VStack spacing above `controlBar` when at least one pill
	/// has content — mirrors the visibility checks inside the pill views.
	@ViewBuilder
	private var hudPillRow: some View {
		if hasMusicPill || hasVersionPill || hasStatusPill {
			HStack {
				Spacer(minLength: 16)
				HStack(alignment: .bottom, spacing: 8) {
					if hasMusicPill {
						MusicHUDPill(
							settings: settings,
							musicTitle: musicController.currentMusicTitle,
							accentColor: accentColor,
							hudTintColor: hudTintColor,
							openCurrentMusicURL: musicController.openCurrentMusicURL,
							controller: musicController
						)
						.transition(hudPillTransition)
					}
					if hasVersionPill {
						VersionHUDPill(
							lifecycle: lifecycle,
							installation: installation,
							gameSession: gameSession,
							accentColor: accentColor,
							hudTintColor: hudTintColor,
							checkGameUpdates: checkGameUpdates
						)
						.transition(hudPillTransition)
					}
					if hasStatusPill {
						StatusHUDPill(
							settings: settings,
							installation: installation,
							canSwitchRegion: canSwitchRegion,
							accentColor: accentColor,
							hudTintColor: hudTintColor,
							selectRegion: selectRegion
						)
						.transition(hudPillTransition)
					}
				}
			}
			.padding(.trailing, AppConstants.HUD.pillRowTrailingInset)
			.transition(hudPillTransition)
			.animation(stateAnimation, value: hasMusicPill)
			.animation(stateAnimation, value: hasVersionPill)
			.animation(stateAnimation, value: hasStatusPill)
		}
	}

	private var hasMusicPill: Bool {
		settings.showsPlayingMusic && musicController.currentMusicTitle != nil
	}

	private var hasVersionPill: Bool {
		settings.showsGameVersion && versionText != "—"
	}

	private var hasStatusPill: Bool {
		settings.resetCountdownText != nil
	}

	private var primaryActionIdentity: String {
		if gameSession.isGameActive { return "stop" }
		if installation.isDownloading { return "pause" }
		if !installation.isInstalled {
			return installation.hasPartialDownload ? "resume" : "install"
		}
		if installation.isGameUpdateAvailable { return "update" }
		return "play"
	}

	private var versionText: String {
		installation.installedVersion
			?? installation.configuration?.gameLatestVersion
			?? "—"
	}

	private var stateAnimation: Animation? {
		reduceMotion ? nil : .easeInOut(duration: 0.2)
	}

	private var primaryActionTransition: AnyTransition {
		reduceMotion ? .opacity : .scale(scale: 0.94).combined(with: .opacity)
	}

	private var hudPillTransition: AnyTransition {
		reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
	}
}
