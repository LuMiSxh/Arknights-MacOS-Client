// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct ContentView: View {
	let model: LauncherViewModel
	let registerOpenSettings: (@escaping () -> Void) -> Void
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var settingsPresented = false
	@State private var launcherUpdateCheckAfterSettingsDismiss = false
	@State private var confirmsRosettaInstallation = false
	@State private var onboarding: OnboardingCoordinator
	@State private var musicController: BackgroundMusicController
	init(
		model: LauncherViewModel,
		registerOpenSettings: @escaping (@escaping () -> Void) -> Void
	) {
		self.model = model
		self.registerOpenSettings = registerOpenSettings
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

			LauncherArtworkView(
				image: model.customization.heroArtwork,
				themeCacheKey: model.customization.activeThemeCacheKey,
				accentColor: accentColor
			)
			.ignoresSafeArea(.container, edges: .top)

			LauncherReadabilityField()
				.ignoresSafeArea(.container, edges: .top)
				.allowsHitTesting(false)

			VStack(spacing: 0) {
				topBar
				Spacer()
				LauncherHUDView(
					model: model,
					accentColor: accentColor,
					hudTintColor: model.customization.hudTintColor,
					musicController: musicController,
					requestRosettaInstallation: { confirmsRosettaInstallation = true },
					retryIntelTranslationCheck: retryIntelTranslationCheck
				)
			}
			// Re-key because L10n reads a mutex and SwiftUI otherwise misses language changes.
			.id(model.settings.appLanguage)
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
		.sheet(isPresented: $settingsPresented, onDismiss: openLauncherUpdateAfterSettingsDismiss) {
			LauncherSettingsView(
				model: model,
				restartOnboarding: restartOnboarding,
				requestLauncherUpdateCheck: requestLauncherUpdateCheck
			)
		}
		.overlay {
			if model.communication.launcherUpdateUserDriver.isPresented {
				ZStack {
					Color.black.opacity(0.55).ignoresSafeArea()
					LauncherUpdateView(
						driver: model.communication.launcherUpdateUserDriver,
						accentColor: accentColor,
						hudTintColor: model.customization.hudTintColor,
						checkForUpdates: model.communication.openLauncherUpdate
					)
				}
			}
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
		.onAppear {
			registerOpenSettings(presentSettings)
		}
		.task {
			await startOnboardingIfNeeded()
		}
	}

	private var popupBinding: Binding<LauncherPopup?> {
		Binding(
			get: {
				guard !onboarding.isPresented,
					!model.communication.launcherUpdateUserDriver.isPresented
				else { return nil }
				return model.communication.popup
			},
			set: { popup in
				if popup == nil { model.communication.dismissPopup() }
			}
		)
	}

	private var topBar: some View {
		HStack(alignment: .top) {
			ArknightsWordmark(
				logo: model.customization.officialLogo,
				region: model.installation.region
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
			.frame(minWidth: 44, minHeight: 44)
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

	private func requestLauncherUpdateCheck() {
		launcherUpdateCheckAfterSettingsDismiss = true
		settingsPresented = false
	}

	private func openLauncherUpdateAfterSettingsDismiss() {
		guard launcherUpdateCheckAfterSettingsDismiss else { return }
		launcherUpdateCheckAfterSettingsDismiss = false
		model.communication.openLauncherUpdate()
	}

	private func startOnboardingIfNeeded() async {
		await model.waitForStartup()
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

	private var themeAnimation: Animation? {
		reduceMotion ? nil : .easeInOut(duration: 0.3)
	}
}
