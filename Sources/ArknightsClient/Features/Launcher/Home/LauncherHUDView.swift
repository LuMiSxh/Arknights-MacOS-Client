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
	let actions: LauncherHUDActions
	let developerExpandedPill: String?
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var expandedPill: ExpandedPill?

	var body: some View {
		ZStack(alignment: .bottom) {
			Color.clear
				.contentShape(Rectangle())
				.onTapGesture(perform: collapseExpandedPill)

			VStack(spacing: 10) {
				hudPillRow
				controlBar
			}
			.padding(20)
		}
		.onChange(of: hasMusicPill) { _, _ in collapseUnavailablePill() }
		.onChange(of: hasVersionPill) { _, _ in collapseUnavailablePill() }
		.onChange(of: hasStatusPill) { _, _ in collapseUnavailablePill() }
		.onAppear(perform: syncDeveloperExpandedPill)
		.onChange(of: developerExpandedPill) { _, _ in syncDeveloperExpandedPill() }
	}

	private var controlBar: some View {
		HStack(spacing: 16) {
			LauncherActivityStatusView(
				lifecycle: lifecycle,
				installation: installation,
				intelTranslation: intelTranslation,
				accentColor: accentColor,
				requestRosettaInstallation: actions.requestRosettaInstallation,
				retryIntelTranslationCheck: actions.retryIntelTranslationCheck
			)
			.id(installation.isDownloading ? "download-progress" : "launcher-status")
			.transition(.opacity)
			.frame(maxWidth: .infinity, alignment: .leading)

			HStack(spacing: 8) {
				if communication.shouldShowLauncherUpdateButton {
					CapsuleActionButton(
						title: HomeStrings.launcherUpdate,
						systemImage: "arrow.down.app",
						tone: .neutral,
						action: actions.openLauncherUpdate
					)
					.disabled(!communication.canOpenLauncherUpdate)
					.transition(.opacity)
					.help(HomeStrings.launcherUpdateHelp)
				}

				if lifecycle.failure?.blocksGameLaunch == true {
					CapsuleActionButton(
						title: HomeStrings.recoveryDetails,
						systemImage: "info.circle",
						tone: .neutral,
						action: actions.showFailureDetails
					)
					.controlSize(.large)
					.transition(primaryActionTransition)
				}

				LauncherPrimaryActionView(
					installation: installation,
					gameSession: gameSession,
					intelTranslation: intelTranslation,
					accentColor: accentColor,
					installOrUpdate: actions.installOrUpdate,
					cancelDownload: actions.cancelDownload,
					launch: actions.launch,
					stopGame: actions.stopGame
				)
				.disabled(lifecycle.failure?.blocksGameLaunch == true)
				.transaction { transaction in
					transaction.animation = nil
				}
			}
		}
		.padding(16)
		.hudPillSurface(
			progress: LauncherDownloadProgressPresentation.outlineFraction(
				for: installation.progress,
				status: lifecycle.presentation.status,
				hasPartialDownload: installation.hasPartialDownload,
				hasFailure: lifecycle.failure != nil
			),
			isProgressActive: LauncherDownloadProgressPresentation.showsActiveProgressEffect(
				for: installation.progress,
				status: lifecycle.presentation.status,
				hasFailure: lifecycle.failure != nil
			),
			tint: hudTintColor,
			progressTint: accentColor
		)
		.animation(stateAnimation, value: installation.isDownloading)
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
							controller: musicController,
							isExpanded: expandedBinding(for: .music)
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
							checkGameUpdates: actions.checkGameUpdates,
							isExpanded: expandedBinding(for: .version)
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
							selectRegion: actions.selectRegion,
							isExpanded: expandedBinding(for: .status)
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

	private func expandedBinding(for pill: ExpandedPill) -> Binding<Bool> {
		Binding(
			get: { expandedPill == pill },
			set: { isExpanded in
				if isExpanded {
					expandedPill = pill
				} else if expandedPill == pill {
					expandedPill = nil
				}
			}
		)
	}

	private func collapseUnavailablePill() {
		guard
			(expandedPill == .music && !hasMusicPill)
				|| (expandedPill == .version && !hasVersionPill)
				|| (expandedPill == .status && !hasStatusPill)
		else { return }
		expandedPill = nil
	}

	private func collapseExpandedPill() {
		guard expandedPill != nil else { return }
		withAnimation(HUDPillMotion.expansionAnimation(reduceMotion: reduceMotion)) {
			expandedPill = nil
		}
	}

	private func syncDeveloperExpandedPill() {
		switch developerExpandedPill {
		case "music": expandedPill = .music
		case "version": expandedPill = .version
		case "status": expandedPill = .status
		default: expandedPill = nil
		}
	}

	private enum ExpandedPill {
		case music
		case version
		case status
	}
}
