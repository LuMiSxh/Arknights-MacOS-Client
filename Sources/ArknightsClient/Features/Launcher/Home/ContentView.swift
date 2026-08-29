// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct ContentView: View {
	let model: LauncherViewModel
	let registerOpenSettings: (@escaping () -> Void) -> Void
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var settingsPresented = false
	@State private var launcherUpdateCheckAfterSettingsDismiss = false
	@State private var confirmsRosettaInstallation = false
	@State private var confirmsRepair = false
	@State private var repairFailureID: UUID?
	@State private var presentedFailure: LauncherFailurePresentation?
	@State private var failureAfterSettingsDismiss: LauncherFailurePresentation?
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
		_presentedFailure = State(initialValue: model.lifecycle.failure)
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
					retryIntelTranslationCheck: retryIntelTranslationCheck,
					showFailureDetails: showFailureDetails
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
		.sheet(isPresented: $settingsPresented, onDismiss: settingsDidDismiss) {
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
		.sheet(item: $presentedFailure, onDismiss: failureDetailsDidDismiss) { failure in
			LauncherFailureDetailView(
				failure: failure,
				accentColor: accentColor,
				hudTintColor: model.customization.hudTintColor,
				perform: performRecoveryAction
			)
		}
		.confirmsRosettaInstallation(
			isPresented: $confirmsRosettaInstallation,
			install: installRosetta
		)
		.confirmationDialog(
			L10n.string(HomeStrings.repairConfirmationTitle),
			isPresented: $confirmsRepair,
			titleVisibility: .visible
		) {
			Button(
				L10n.string(HomeStrings.repairConfirmationAction),
				action: confirmRepair
			)
			Button(L10n.string(LauncherStrings.cancel), role: .cancel) {
				cancelRepair()
			}
		} message: {
			Text(HomeStrings.repairConfirmationDetail)
		}
		.onAppear {
			registerOpenSettings(presentSettings)
		}
		.onChange(of: model.lifecycle.failure) { _, failure in
			presentFailure(failure)
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

	private func settingsDidDismiss() {
		if let failureAfterSettingsDismiss,
			model.lifecycle.failure?.id == failureAfterSettingsDismiss.id
		{
			self.failureAfterSettingsDismiss = nil
			presentedFailure = failureAfterSettingsDismiss
			return
		}
		failureAfterSettingsDismiss = nil
		openLauncherUpdateAfterSettingsDismiss()
	}

	private func presentFailure(_ failure: LauncherFailurePresentation?) {
		guard let failure else {
			failureAfterSettingsDismiss = nil
			presentedFailure = nil
			return
		}
		if settingsPresented {
			failureAfterSettingsDismiss = failure
			settingsPresented = false
		} else {
			presentedFailure = failure
		}
	}

	private func startOnboardingIfNeeded() async {
		await model.waitForStartup()
		if model.isDeveloperMode, !model.isOnboardingPreview { return }
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
		Task { await model.installRosetta() }
	}

	private func performRecoveryAction(_ action: RecoveryAction, failureID: UUID) {
		if model.performRecoveryAction(action, failureID: failureID)
			== .repairConfirmationRequired
		{
			presentedFailure = nil
			repairFailureID = failureID
			confirmsRepair = true
		}
	}

	private func showFailureDetails() {
		presentedFailure = model.lifecycle.failure
	}

	private func failureDetailsDidDismiss() {
		guard repairFailureID == nil else { return }
		if model.lifecycle.failure?.blocksGameLaunch == false {
			model.lifecycle.clearFailure()
		}
	}

	private func cancelRepair() {
		repairFailureID = nil
		if model.lifecycle.failure?.blocksGameLaunch == false {
			model.lifecycle.clearFailure()
		}
	}

	private func confirmRepair() {
		guard let repairFailureID else { return }
		self.repairFailureID = nil
		model.confirmRepair(failureID: repairFailureID)
	}

	private var themeAnimation: Animation? {
		reduceMotion ? nil : .easeInOut(duration: 0.3)
	}
}
