// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct ContentView: View {
	let model: LauncherViewModel
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var settingsPresented = false
	@State private var confirmsRosettaInstallation = false
	@State private var onboarding: OnboardingCoordinator
	@State private var musicController: BackgroundMusicController

	init(model: LauncherViewModel) {
		self.model = model
		_onboarding = State(
			initialValue: OnboardingCoordinator(
				store: OnboardingProgressStore(defaults: model.preferences.defaults)
			)
		)
		_musicController = State(initialValue: BackgroundMusicController(context: model))
	}

	private var accentColor: Color { model.customization.accentColor }

	var body: some View {
		ZStack {
			BackgroundMusicView(
				lifecycle: model.lifecycle,
				settings: model.settings,
				gameSession: model.gameSession,
				controller: musicController
			)

			LauncherArtworkView(image: model.customization.heroArtwork, accentColor: accentColor)
				.ignoresSafeArea(.container, edges: .top)

			LinearGradient(
				colors: [
					Color.black.opacity(0.62),
					Color.black.opacity(0.32),
					Color.clear,
				],
				startPoint: .topLeading,
				endPoint: .init(x: 0.38, y: 0.28)
			)
			.ignoresSafeArea(.container, edges: .top)
			.allowsHitTesting(false)

			VStack(spacing: 0) {
				topBar
				Spacer()
				VStack(spacing: 10) {
					hudPillRow
					controlBar
				}
				.padding(20)
			}
		}
		.background(Color.black)
		.preferredColorScheme(.dark)
		.animation(themeAnimation, value: model.customization.dynamicThemeHue)
		.overlay {
			if onboarding.isPresented {
				OnboardingView(
					model: model,
					coordinator: onboarding,
					retryUpdateCheck: retryOnboardingUpdateCheck
				)
			}
		}
		.sheet(isPresented: $settingsPresented) {
			LauncherSettingsView(model: model, restartOnboarding: restartOnboarding)
		}
		.sheet(item: popupBinding) { popup in
			LauncherPopupView(
				popup: popup,
				accentColor: accentColor,
				hudTintColor: model.customization.hudTintColor,
				dismiss: model.communication.dismissPopup,
				openAction: model.communication.openPopupAction
			)
		}
		.confirmsRosettaInstallation(
			isPresented: $confirmsRosettaInstallation,
			install: installRosetta
		)
		.task {
			await startOnboardingIfNeeded()
		}
	}

	private var popupBinding: Binding<LauncherPopup?> {
		Binding(
			get: { onboarding.isPresented ? nil : model.communication.popup },
			set: { popup in
				if popup == nil { model.communication.dismissPopup() }
			}
		)
	}

	private var topBar: some View {
		HStack(alignment: .top) {
			ArknightsWordmark(
				logo: model.customization.officialLogo,
				regionName: model.installation.region.localizedDisplayName,
				cyan: accentColor
			)
			.padding(.top, 34)
			Spacer()
			Button(
				L10n.string(HomeStrings.settings),
				systemImage: "gearshape",
				action: presentSettings
			)
			.labelStyle(.iconOnly)
			.font(.system(size: 23, weight: .medium))
			.frame(width: 30, height: 30)
			.adaptiveGlassButton()
			.buttonBorderShape(.circle)
			.controlSize(.extraLarge)
			.keyboardShortcut(",", modifiers: .command)
			.help(L10n.string(HomeStrings.settingsHelp))
		}
		.padding(.top, 8)
		.padding(.horizontal, 14)
		.ignoresSafeArea(.container, edges: .top)
	}

	private func presentSettings() {
		settingsPresented = true
	}

	private func startOnboardingIfNeeded() async {
		model.installation.updateInstalledState()
		await onboarding.startIfNeeded(
			isDeveloperMode: model.isDeveloperMode,
			isOnboardingPreview: model.isOnboardingPreview,
			gameIsInstalled: model.installation.isInstalled,
			checkForUpdates: model.launcherUpdateCheckForOnboarding,
			checkIntelTranslation: { await model.intelTranslation.refreshAvailability() }
		)
	}

	private func retryOnboardingUpdateCheck() {
		Task {
			await onboarding.retryUpdateCheck(
				model.launcherUpdateCheckForOnboarding,
				checkIntelTranslation: { await model.intelTranslation.refreshAvailability() }
			)
		}
	}

	private func restartOnboarding() {
		settingsPresented = false
		model.installation.updateInstalledState()
		Task {
			await onboarding.restart(
				gameIsInstalled: model.installation.isInstalled,
				checkForUpdates: model.launcherUpdateCheckForOnboarding,
				checkIntelTranslation: { await model.intelTranslation.refreshAvailability() }
			)
		}
	}

	private func retryIntelTranslationCheck() {
		Task {
			await model.intelTranslation.refreshAvailability(force: true)
		}
	}

	private func installRosetta() {
		Task { await model.intelTranslation.installRosetta() }
	}

	private var controlBar: some View {
		HStack(spacing: 16) {
			LauncherActivityStatusView(
				lifecycle: model.lifecycle,
				installation: model.installation,
				intelTranslation: model.intelTranslation,
				accentColor: accentColor,
				requestRosettaInstallation: { confirmsRosettaInstallation = true },
				retryIntelTranslationCheck: retryIntelTranslationCheck
			)
			.id(model.installation.isDownloading ? "download-progress" : "launcher-status")
			.transition(.opacity)
			.frame(maxWidth: .infinity, alignment: .leading)

			HStack(spacing: 8) {
				if model.communication.launcherUpdate != nil {
					CapsuleActionButton(
						title: L10n.string(HomeStrings.launcherUpdate),
						systemImage: "arrow.down.app",
						tone: .accent(accentColor),
						action: model.communication.openLauncherUpdate
					)
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
				.id(primaryActionIdentity)
				.transition(primaryActionTransition)
			}
		}
		.padding(16)
		.adaptiveGlassEffect(tint: model.customization.hudTintColor, in: Capsule())
		.animation(stateAnimation, value: model.installation.isDownloading)
		.animation(stateAnimation, value: primaryActionIdentity)
		.animation(stateAnimation, value: model.communication.launcherUpdate != nil)
	}

	/// Only takes up the 10pt of VStack spacing above `controlBar` when at least one pill
	/// has content — mirrors the visibility checks inside `MusicHUDPill`/`VersionHUDPill`/
	/// `StatusHUDPill` so the common case (no music, single region) doesn't leave a stray gap.
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
							hudTintColor: model.customization.hudTintColor,
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
							hudTintColor: model.customization.hudTintColor,
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
							hudTintColor: model.customization.hudTintColor,
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

	private var themeAnimation: Animation? {
		reduceMotion ? nil : .easeInOut(duration: 0.3)
	}

	private var primaryActionTransition: AnyTransition {
		reduceMotion ? .opacity : .scale(scale: 0.94).combined(with: .opacity)
	}

	private var hudPillTransition: AnyTransition {
		reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
	}
}
