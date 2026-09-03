// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct ContentView: View {
	let model: LauncherViewModel
	let initialMusicTitle: String?
	let openMusicURL: (URL) -> Void
	let registerOpenSettings: (@escaping () -> Void) -> Void
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
	@State private var presentation = LauncherPresentationArbiter()
	@State private var confirmation: LauncherConfirmation?
	@State private var repairFailureID: UUID?
	@State private var onboarding: OnboardingCoordinator
	@State private var musicController: BackgroundMusicController

	init(
		model: LauncherViewModel,
		initialMusicTitle: String?,
		openMusicURL: @escaping (URL) -> Void,
		registerOpenSettings: @escaping (@escaping () -> Void) -> Void
	) {
		self.model = model
		self.initialMusicTitle = initialMusicTitle
		self.openMusicURL = openMusicURL
		self.registerOpenSettings = registerOpenSettings
		_onboarding = State(
			initialValue: OnboardingCoordinator(
				store: OnboardingProgressStore(defaults: model.preferences.defaults)))
		_musicController = State(
			initialValue: BackgroundMusicController(
				lifecycle: model.lifecycle,
				settings: model.settings,
				launcherIconManager: model.launcherIconManager,
				initialMusicTitle: initialMusicTitle,
				openURL: openMusicURL))
	}

	var body: some View {
		ZStack {
			BackgroundMusicView(
				lifecycle: model.lifecycle, settings: model.settings, controller: musicController)
			LauncherArtworkView(
				image: model.customization.heroArtwork,
				themeCacheKey: model.customization.activeThemeCacheKey,
				accentColor: model.customization.accentColor
			)
			.ignoresSafeArea(.container, edges: .top)
			LauncherReadabilityField().ignoresSafeArea(.container, edges: .top).allowsHitTesting(
				false)
			VStack(spacing: 0) {
				topBar
				Spacer()
				LauncherHUDView(
					lifecycle: model.lifecycle,
					settings: model.settings,
					installation: model.installation,
					gameSession: model.gameSession,
					intelTranslation: model.intelTranslation,
					communication: model.communication,
					canSwitchRegion: model.refreshController.canSwitchRegion,
					accentColor: model.customization.accentColor,
					hudTintColor: model.customization.hudTintColor,
					musicController: musicController,
					openLauncherUpdate: requestLauncherUpdateCheck,
					checkGameUpdates: model.checkGameUpdates,
					selectRegion: { model.selectRegion($0) },
					installOrUpdate: model.installOrUpdate,
					cancelDownload: model.cancelDownload,
					launch: model.launch,
					stopGame: model.stopGame,
					requestRosettaInstallation: { confirmation = .rosetta },
					retryIntelTranslationCheck: retryIntelTranslationCheck,
					showFailureDetails: showFailureDetails)
			}
			.id(model.settings.appLanguage)
		}
		.background(Color.black)
		.preferredColorScheme(.dark)
		.animation(themeAnimation, value: model.customization.dynamicThemeHue)
		.overlay {
			if onboardingIsPresentable {
				OnboardingView(
					preferences: model.settings,
					customization: model.customization,
					installation: model.installation,
					lifecycle: model.lifecycle,
					presetCatalog: model.presetCatalog,
					canSwitchRegion: model.refreshController.canSwitchRegion,
					coordinator: onboarding,
					actions: OnboardingActions(
						selectRegion: model.selectRegion,
						resetArtwork: model.resetArtwork,
						installOrUpdate: model.installOrUpdate,
						openLauncherUpdate: model.communication.openLauncherUpdate,
						retryIntelTranslation: {
							await model.intelTranslation.refreshAvailability(force: true)
						},
						installRosetta: model.installRosetta),
					retryUpdateCheck: retryOnboardingUpdateCheck)
			}
		}
		.sheet(item: sheetPresentation, onDismiss: presentationDidDismiss) { sheetContent(for: $0) }
		.overlay {
			if presentation.current == .update,
				model.communication.launcherUpdateUserDriver.isPresented
			{
				ZStack {
					(reduceTransparency ? Color.black : Color.black.opacity(0.55)).ignoresSafeArea()
					LauncherUpdateView(
						driver: model.communication.launcherUpdateUserDriver,
						accentColor: model.customization.accentColor,
						hudTintColor: model.customization.hudTintColor,
						checkForUpdates: model.communication.openLauncherUpdate)
				}
			}
		}
		.confirmsRosettaInstallation(
			isPresented: rosettaConfirmationBinding, install: installRosetta
		)
		.confirmationDialog(
			L10n.string(HomeStrings.repairConfirmationTitle),
			isPresented: repairConfirmationBinding,
			titleVisibility: .visible
		) {
			Button(L10n.string(HomeStrings.repairConfirmationAction), action: confirmRepair)
			Button(L10n.string(LauncherStrings.cancel), role: .cancel, action: cancelRepair)
		} message: {
			Text(L10n.string(HomeStrings.repairConfirmationDetail))
		}
		.onAppear { registerOpenSettings(requestSettings) }
		.onChange(of: model.lifecycle.failure) { _, failure in presentFailure(failure) }
		.onChange(of: model.communication.launcherUpdateUserDriver.isPresented) { _, isPresented in
			if isPresented {
				presentation.request(.update)
			} else {
				launcherUpdateDidDismiss()
			}
		}
		.task { await startOnboardingIfNeeded() }
	}

	private var sheetPresentation: Binding<LauncherPresentationDestination?> {
		Binding(
			get: {
				if let current = presentation.current, current.isSheet { return current }
				guard presentation.current == nil, !onboarding.isPresented,
					!model.communication.launcherUpdateUserDriver.isPresented,
					model.communication.popup != nil
				else { return nil }
				return .popup
			},
			set: { destination in
				guard destination == nil else { return }
				if presentation.current == nil, model.communication.popup != nil {
					model.communication.dismissPopup()
				} else {
					presentation.dismissCurrent()
				}
			})
	}

	private var rosettaConfirmationBinding: Binding<Bool> {
		Binding(get: { confirmation == .rosetta }, set: { if !$0 { confirmation = nil } })
	}
	private var repairConfirmationBinding: Binding<Bool> {
		Binding(
			get: { if case .repair = confirmation { true } else { false } },
			set: { if !$0 { confirmation = nil } })
	}
	private var onboardingIsPresentable: Bool {
		onboarding.isPresented && presentation.current == nil && model.communication.popup == nil
	}

	@ViewBuilder
	private func sheetContent(for destination: LauncherPresentationDestination) -> some View {
		switch destination {
		case .settings:
			LauncherSettingsView(
				settings: model.settings, customization: model.customization,
				communication: model.communication,
				installation: model.installation, gameSession: model.gameSession,
				lifecycle: model.lifecycle,
				storage: model.storage, storageOverview: model.storageOverview,
				playtimeStatistics: model.playtimeStatistics, presetCatalog: model.presetCatalog,
				launcherIconManager: model.launcherIconManager,
				branding: model.refreshController.branding,
				resetArtwork: model.resetArtwork, checkGameUpdates: model.checkGameUpdates,
				selectRegion: { model.selectRegion($0) },
				chooseInstallDirectory: model.chooseInstallDirectory,
				locateExistingInstallation: model.locateExistingInstallation,
				repairGame: model.repairGame,
				resetAllLauncherSettings: model.resetAllLauncherSettings,
				uninstallGame: model.uninstallGame,
				restartOnboarding: restartOnboarding,
				requestLauncherUpdateCheck: requestLauncherUpdateCheck,
				developerScenario: developerScenarioBinding, applyCustomPopup: developerPopup)
		case .failure(let failure):
			LauncherFailureDetailView(
				failure: failure, accentColor: model.customization.accentColor,
				hudTintColor: model.customization.hudTintColor, perform: performRecoveryAction
			)
			.onDisappear(perform: failureDetailsDidDismiss)
		case .popup:
			if let popup = model.communication.popup {
				LauncherPopupView(
					popup: popup, accentColor: model.customization.accentColor,
					hudTintColor: model.customization.hudTintColor,
					dismiss: model.communication.dismissPopup,
					openAction: model.communication.openPopupAction)
			} else {
				EmptyView()
			}
		case .update: EmptyView()
		}
	}

	private var topBar: some View {
		HStack(alignment: .top) {
			ArknightsWordmark(
				logo: model.customization.officialLogo, region: model.installation.region
			).padding(.top, 34)
			Spacer()
			Button(
				L10n.string(HomeStrings.settings), systemImage: "gearshape", action: requestSettings
			)
			.labelStyle(.iconOnly).font(.title2.weight(.medium)).frame(minWidth: 44, minHeight: 44)
			.adaptiveGlassButton().buttonBorderShape(.circle).controlSize(.extraLarge)
			.keyboardShortcut(",", modifiers: .command).help(L10n.string(HomeStrings.settingsHelp))
		}
		.padding(.top, 8).padding(.horizontal, 14).ignoresSafeArea(.container, edges: .top)
	}

	private func requestSettings() {
		guard !onboarding.isPresented, !model.communication.launcherUpdateUserDriver.isPresented,
			model.communication.popup == nil, presentation.current == nil
		else { return }
		presentation.request(.settings)
	}
	private func requestLauncherUpdateCheck() {
		let hadCurrentPresentation = presentation.current != nil
		presentation.request(.update)
		if !hadCurrentPresentation, presentation.current == .update {
			model.communication.openLauncherUpdate()
		}
	}
	private func presentationDidDismiss() {
		presentation.didDismiss()
		if presentation.current == .update { model.communication.openLauncherUpdate() }
	}
	private func launcherUpdateDidDismiss() {
		presentation.didDismiss(.update)
		if presentation.current == .update { model.communication.openLauncherUpdate() }
	}
	private func presentFailure(_ failure: LauncherFailurePresentation?) {
		guard let failure else {
			presentation.removeFailures()
			return
		}
		let previous = presentation.current
		presentation.request(.failure(failure))
		if previous == .update { model.communication.launcherUpdateUserDriver.dismissFromUser() }
	}
	private func startOnboardingIfNeeded() async {
		guard await model.waitForStartup() else { return }
		if model.isDeveloperMode, !model.isOnboardingPreview { return }
		await model.installation.updateInstalledState().value
		await onboarding.startIfNeeded(
			isDeveloperMode: model.isDeveloperMode,
			isOnboardingPreview: model.isOnboardingPreview,
			gameIsInstalled: model.installation.isInstalled,
			checkForUpdates: model.launcherUpdateCheckForOnboarding,
			checkIntelTranslation: { await model.intelTranslation.refreshAvailability() })
	}
	private func retryOnboardingUpdateCheck() {
		Task {
			await onboarding.retryUpdateCheck(
				model.launcherUpdateCheckForOnboarding,
				checkIntelTranslation: { await model.intelTranslation.refreshAvailability() })
		}
	}
	private func restartOnboarding() {
		guard model.lifecycle.activity != .maintaining(.migratingStorage) else { return }
		presentation.dismissCurrent()
		Task {
			await model.installation.updateInstalledState().value
			await onboarding.restart(
				gameIsInstalled: model.installation.isInstalled,
				checkForUpdates: model.launcherUpdateCheckForOnboarding,
				checkIntelTranslation: { await model.intelTranslation.refreshAvailability() })
		}
	}
	private func retryIntelTranslationCheck() {
		Task { await model.intelTranslation.refreshAvailability(force: true) }
	}
	private func installRosetta() {
		confirmation = nil
		Task { _ = await model.installRosetta() }
	}
	private func performRecoveryAction(_ action: RecoveryAction, _ failureID: UUID) {
		if model.performRecoveryAction(action, failureID: failureID) == .repairConfirmationRequired
		{
			presentation.dismissCurrent()
			repairFailureID = failureID
			confirmation = .repair(failureID)
		}
	}
	private func showFailureDetails() {
		if let failure = model.lifecycle.failure { presentation.request(.failure(failure)) }
	}
	private func failureDetailsDidDismiss() {
		guard repairFailureID == nil else { return }
		if model.lifecycle.failure?.blocksGameLaunch == false { model.lifecycle.clearFailure() }
	}
	private func cancelRepair() {
		confirmation = nil
		repairFailureID = nil
		if model.lifecycle.failure?.blocksGameLaunch == false { model.lifecycle.clearFailure() }
	}
	private func confirmRepair() {
		guard let id = repairFailureID else { return }
		confirmation = nil
		repairFailureID = nil
		model.confirmRepair(failureID: id)
	}

	#if DEBUG
		private var developerScenarioBinding: DeveloperScenarioBinding? {
			guard model.isDeveloperMode else { return nil }
			return Binding(
				get: { model.developerScenario ?? .ready },
				set: { model.applyDeveloperScenario($0) })
		}
		private var developerPopup: ((String, String) -> Void)? {
			guard model.isDeveloperMode else { return nil }
			return { title, message in
				model.applyDeveloperCustomPopup(title: title, markdown: message)
			}
		}
	#else
		private var developerScenarioBinding: DeveloperScenarioBinding? { nil }
		private var developerPopup: ((String, String) -> Void)? { nil }
	#endif

	private var themeAnimation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.3) }
}
