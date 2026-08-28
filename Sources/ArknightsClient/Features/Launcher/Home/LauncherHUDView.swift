// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct LauncherHUDView: View {
	let model: LauncherViewModel
	let accentColor: Color
	let hudTintColor: Color
	let musicController: BackgroundMusicController
	let requestRosettaInstallation: () -> Void
	let retryIntelTranslationCheck: () -> Void
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
				lifecycle: model.lifecycle,
				installation: model.installation,
				intelTranslation: model.intelTranslation,
				accentColor: accentColor,
				requestRosettaInstallation: requestRosettaInstallation,
				retryIntelTranslationCheck: retryIntelTranslationCheck
			)
			.id(model.installation.isDownloading ? "download-progress" : "launcher-status")
			.transition(.opacity)
			.frame(maxWidth: .infinity, alignment: .leading)

			HStack(spacing: 8) {
				if model.communication.shouldShowLauncherUpdateButton {
					CapsuleActionButton(
						title: L10n.string(HomeStrings.launcherUpdate),
						systemImage: "arrow.down.app",
						tone: .accent(accentColor),
						action: model.communication.openLauncherUpdate
					)
					.disabled(!model.communication.canOpenLauncherUpdate)
					.transition(.opacity)
					.help(L10n.string(HomeStrings.launcherUpdateHelp))
				}

				LauncherPrimaryActionView(
					installation: model.installation,
					gameSession: model.gameSession,
					intelTranslation: model.intelTranslation,
					accentColor: accentColor,
					installOrUpdate: model.installOrUpdate,
					cancelDownload: model.cancelDownload,
					launch: model.launch,
					stopGame: model.stopGame
				)
				.transition(primaryActionTransition)
			}
		}
		.padding(16)
		.adaptiveGlassEffect(tint: hudTintColor, in: Capsule())
		.animation(stateAnimation, value: model.installation.isDownloading)
		.animation(stateAnimation, value: primaryActionIdentity)
		.animation(stateAnimation, value: model.communication.shouldShowLauncherUpdateButton)
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
							settings: model.settings,
							gameSession: model.gameSession,
							musicTitle: model.currentMusicTitle,
							accentColor: accentColor,
							hudTintColor: hudTintColor,
							openCurrentMusicURL: model.openCurrentMusicURL,
							controller: musicController
						)
						.transition(hudPillTransition)
					}
					if hasVersionPill {
						VersionHUDPill(
							lifecycle: model.lifecycle,
							installation: model.installation,
							gameSession: model.gameSession,
							accentColor: accentColor,
							hudTintColor: hudTintColor,
							checkGameUpdates: model.checkGameUpdates
						)
						.transition(hudPillTransition)
					}
					if hasStatusPill {
						StatusHUDPill(
							settings: model.settings,
							installation: model.installation,
							canSwitchRegion: model.refreshController.canSwitchRegion,
							accentColor: accentColor,
							hudTintColor: hudTintColor,
							selectRegion: { model.selectRegion($0) }
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
		model.settings.showsPlayingMusic && model.currentMusicTitle != nil
	}

	private var hasVersionPill: Bool {
		model.settings.showsGameVersion && versionText != "—"
	}

	private var hasStatusPill: Bool {
		model.settings.resetCountdownText != nil
			|| model.installation.installedRegions.count > 1
			|| model.installation.region != .global
	}

	private var primaryActionIdentity: String {
		if model.gameSession.isGameActive { return "stop" }
		if model.installation.isDownloading { return "pause" }
		if !model.installation.isInstalled {
			return model.installation.hasPartialDownload ? "resume" : "install"
		}
		if model.installation.isGameUpdateAvailable { return "update" }
		return "play"
	}

	private var versionText: String {
		model.installation.installedVersion
			?? model.installation.configuration?.gameLatestVersion
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
