// SPDX-License-Identifier: MPL-2.0

import ArknightsAudio
import ArknightsCore
import ArknightsGameInstallation
import ArknightsOnboarding
import SwiftUI

package struct ContentView: View {
	let model: LauncherViewModel
	let musicController: BackgroundMusicController
	let onboarding: OnboardingCoordinator
	let registerOpenSettings: (@escaping () -> Void) -> Void
	let registerQuitPresentationQuery: (@escaping () -> LauncherPresentationDestination?) -> Void
	let registerQuitDismissal: (@escaping () -> Void) -> Void
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
	@State package var presentation = LauncherPresentationArbiter()
	@State var confirmation: LauncherConfirmation?
	@State var repairFailureID: UUID?
	@State var decorativeMotionVisibility = DecorativeMotionVisibility()
	@State private var isTerminating = false
	@State private var windowSize = CGSize.zero

	package init(
		model: LauncherViewModel,
		musicController: BackgroundMusicController,
		onboarding: OnboardingCoordinator,
		registerOpenSettings: @escaping (@escaping () -> Void) -> Void,
		registerQuitPresentationQuery:
			@escaping (@escaping () -> LauncherPresentationDestination?) -> Void,
		registerQuitDismissal: @escaping (@escaping () -> Void) -> Void
	) {
		self.model = model
		self.musicController = musicController
		self.onboarding = onboarding
		self.registerOpenSettings = registerOpenSettings
		self.registerQuitPresentationQuery = registerQuitPresentationQuery
		self.registerQuitDismissal = registerQuitDismissal
	}

	// The chain is split in two: as one expression it exceeds the type checker's budget.
	private var presentedContent: some View {
		ZStack {
			BackgroundMusicView(
				lifecycle: model.lifecycle, settings: model.settings, controller: musicController)
			LauncherArtworkView(
				image: model.customization.heroArtwork,
				themeCacheKey: model.customization.activeThemeCacheKey,
				accentColor: model.customization.accentColor
			)
			.ignoresSafeArea(.container, edges: .top)
			.environment(\.decorativeMotionEnabled, homeLayerMotionEnabled)
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
					actions: LauncherHUDActions(
						openLauncherUpdate: requestLauncherUpdateCheck,
						checkGameUpdates: { model.actions.checkGameUpdates() },
						selectRegion: { model.actions.selectRegion($0) },
						installOrUpdate: { model.actions.installOrUpdate() },
						cancelDownload: { model.actions.cancelDownload() },
						launch: { model.actions.launch() },
						stopGame: { model.actions.stopGame() },
						showFailureDetails: showFailureDetails
					),
					developerExpandedPill: developerExpandedPillID
				)
			}
			.environment(\.decorativeMotionEnabled, homeLayerMotionEnabled)
		}
		.disabled(updateOverlayIsPresented)
		.allowsHitTesting(!updateOverlayIsPresented)
		.accessibilityHidden(updateOverlayIsPresented)
		.background(Color.black)
		.background {
			WindowVisibilityReader(visibility: decorativeMotionVisibility)
		}
		.preferredColorScheme(.dark)
		.animation(themeAnimation, value: model.customization.dynamicThemeHue)
		.onChange(of: developerAccessibilityMusicTitle) { _, title in
			guard title != nil else { return }
			musicController.currentMusicTitle = title
		}
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
						selectRegion: { model.actions.selectRegion($0) },
						resetArtwork: { model.actions.resetArtwork() },
						installOrUpdate: { model.actions.installOrUpdate() },
						openLauncherUpdate: { model.actions.openLauncherUpdate() },
						retryIntelTranslation: {
							await model.actions.refreshIntelTranslationForUI(force: true)
						},
						installRosetta: { await model.actions.installRosetta() }),
					retryUpdateCheck: retryOnboardingUpdateCheck)
			}
		}
		.onGeometryChange(for: CGSize.self, of: \.size) { windowSize = $0 }
		.sheet(item: sheetPresentation, onDismiss: presentationDidDismiss) { sheetContent(for: $0) }
		.overlay { updateOverlay }
	}

	package var body: some View {
		presentedContent
			.confirmsRosettaInstallation(
				isPresented: rosettaConfirmationBinding, install: installRosetta
			)
			.confirmationDialog(
				"Repair game files?",
				isPresented: repairConfirmationBinding,
				titleVisibility: .visible
			) {
				Button("Start Repair", action: confirmRepair)
				Button("Cancel", role: .cancel, action: cancelRepair)
			} message: {
				Text(
					"Every game file for this region will be checked. Missing or damaged files will be downloaded again and may use substantial data. Launcher settings and the Wine prefix are preserved."
				)
			}
			.aceWarningConfirmation(model: model)
			.onAppear {
				registerOpenSettings(requestSettings)
				registerQuitPresentationQuery {
					presentation.blockingDestination(
						hasPendingPopup: model.communication.popup != nil)
				}
				registerQuitDismissal(dismissPresentationForQuit)
			}
			.onChange(of: model.lifecycle.state.presentation.failure) { _, failure in
				presentFailure(failure)
			}
			.onChange(of: model.lifecycle.activity.isGameProcessRunning, initial: true) {
				_, isActive in
				gameActivityDidChange(isActive)
			}
			.onChange(of: onboarding.isPresented) { _, isPresented in
				onboardingPresentationDidChange(isPresented)
			}
			.onChange(of: model.isOnboardingPreview) { _, isEnabled in
				Task {
					if isEnabled {
						await startOnboardingIfNeeded()
					} else {
						#if DEBUG
							onboarding.dismissDeveloperPreview()
						#endif
					}
				}
			}
			#if DEBUG
				.onChange(of: model.isRequiredOnboardingPreview) { _, isRequired in
					if model.isOnboardingPreview { onboarding.simulateRequiredSetup(isRequired) }
				}
			#endif
			.onChange(of: model.communication.launcherUpdateUserDriver.isPresented) {
				_, isPresented in
				if isPresented {
					presentation.request(.update)
				} else {
					launcherUpdateDidDismiss()
				}
			}
			.task { await startOnboardingIfNeeded() }
			.overlay { initialArtworkCover }
			// Keep this last so every sheet and overlay inherits the visibility gate.
			.environment(\.decorativeMotionEnabled, decorativeMotionVisibility.isEnabled)
	}

	// Split out of `body`: the full modifier chain exceeds the type checker's budget.
	@ViewBuilder
	private var updateOverlay: some View {
		if updateOverlayIsPresented {
			LauncherUpdateOverlay(
				driver: model.communication.launcherUpdateUserDriver,
				accentColor: model.customization.accentColor,
				hudTintColor: model.customization.hudTintColor,
				reduceTransparency: reduceTransparency,
				checkForUpdates: { model.actions.openLauncherUpdate() })
		}
	}

	@ViewBuilder
	private var initialArtworkCover: some View {
		if !model.customization.hasCompletedInitialArtworkLoad {
			Color.black.ignoresSafeArea()
		}
	}

	var sheetPresentation: Binding<LauncherPresentationDestination?> {
		Binding(
			get: {
				guard !isTerminating else { return nil }
				return presentation.sheetDestination(
					isOnboardingPresented: onboarding.isPresented,
					isUpdatePresented: model.communication.launcherUpdateUserDriver.isPresented,
					hasPendingPopup: model.communication.popup != nil)
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
	var onboardingIsPresentable: Bool {
		presentation.showsOnboarding(isOnboardingPresented: onboarding.isPresented)
	}
	var updateOverlayIsPresented: Bool {
		LauncherUpdateOverlayPresentation.isPresented(
			destination: presentation.current,
			driverIsPresented: model.communication.launcherUpdateUserDriver.isPresented)
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
				resetArtwork: { model.actions.resetArtwork() },
				checkGameUpdates: { model.actions.checkGameUpdates() },
				selectRegion: { model.actions.selectRegion($0) },
				chooseInstallDirectory: { model.actions.chooseInstallDirectory() },
				locateExistingInstallation: { model.actions.locateExistingInstallation() },
				repairGame: { model.actions.repairGame() },
				resetAllLauncherSettings: { model.actions.resetAllLauncherSettings() },
				uninstallGame: { model.actions.uninstallGame() },
				restartOnboarding: restartOnboarding,
				requestLauncherUpdateCheck: requestLauncherUpdateCheck,
				developerSimulation: developerSimulationBinding,
				applyCustomPopup: developerPopup, windowSize: windowSize)
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
			if model.settings.showsBranding {
				ArknightsWordmark(
					logo: model.customization.officialLogo, region: model.installation.region
				).padding(.top, 34)
			}
			Spacer()
			IconActionButton(
				title: "Settings",
				systemImage: "gearshape",
				tone: .neutral,
				foreground: .primary,
				surface: .hud,
				surfaceTint: model.customization.hudTintColor,
				size: 40,
				hitTargetSize: 44,
				action: requestSettings
			)
			.frame(minWidth: 44, minHeight: 44)
			.keyboardShortcut(",", modifiers: .command)
			.accessibilityHint(Text("Open launcher settings"))
			.help("Open launcher settings")
		}
		.padding(.top, 8).padding(.horizontal, 14).ignoresSafeArea(.container, edges: .top)
	}

	/// Closes every sheet and dialog so AppKit accepts the quit, without advancing popup queues.
	private func dismissPresentationForQuit() {
		isTerminating = true
		confirmation = nil
		repairFailureID = nil
		model.actions.cancelACEWarning()
		presentation.dismissCurrent()
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
			model.actions.openLauncherUpdate()
		}
	}
	private func presentationDidDismiss() {
		presentation.didDismiss()
		if presentation.current == .update { model.actions.openLauncherUpdate() }
	}
	private func launcherUpdateDidDismiss() {
		presentation.didDismiss(.update)
		if presentation.current == .update { model.actions.openLauncherUpdate() }
	}
	private func presentFailure(_ failure: LauncherFailurePresentation?) {
		if onboarding.isPresented,
			let operation = failure?.context.operation,
			operation == .intelTranslationPreflight || operation == .rosettaInstallation
		{
			return
		}
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
		if !model.isDeveloperMode {
			await model.installation.updateInstalledState().value
		}
		await onboarding.startIfNeeded(
			isDeveloperMode: model.isDeveloperMode,
			isOnboardingPreview: model.isOnboardingPreview,
			simulatesRequiredSetup: model.isRequiredOnboardingPreview,
			gameIsInstalled: model.installation.isInstalled,
			checkForUpdates: { await model.actions.launcherUpdateCheckForOnboarding() },
			checkIntelTranslation: { await model.actions.refreshIntelTranslationForUI() })
		if onboarding.isPresented { presentation.removeRosettaPreflightFailures() }
	}
	private func retryOnboardingUpdateCheck() {
		Task {
			await onboarding.retryUpdateCheck(
				{ await model.actions.launcherUpdateCheckForOnboarding() },
				checkIntelTranslation: { await model.actions.refreshIntelTranslationForUI() })
		}
	}
	private func restartOnboarding() {
		guard model.lifecycle.activity != .maintaining(.migratingStorage) else { return }
		presentation.dismissCurrent()
		Task {
			if !model.isDeveloperMode {
				await model.installation.updateInstalledState().value
			}
			await onboarding.restart(
				gameIsInstalled: model.installation.isInstalled,
				checkForUpdates: { await model.actions.launcherUpdateCheckForOnboarding() },
				checkIntelTranslation: { await model.actions.refreshIntelTranslationForUI() })
		}
	}
	private func installRosetta() {
		confirmation = nil
		Task { _ = await model.actions.installRosetta() }
	}
	private func showFailureDetails() {
		if let failure = model.lifecycle.state.presentation.failure {
			presentation.request(.failure(failure))
		}
	}
	private func failureDetailsDidDismiss() {
		guard repairFailureID == nil else { return }
		if model.lifecycle.state.presentation.failure?.blocksGameLaunch == false {
			model.lifecycle.clearFailure()
		}
	}
	private func cancelRepair() {
		confirmation = nil
		repairFailureID = nil
		if model.lifecycle.state.presentation.failure?.blocksGameLaunch == false {
			model.lifecycle.clearFailure()
		}
	}
	private func confirmRepair() {
		guard let id = repairFailureID else { return }
		confirmation = nil
		repairFailureID = nil
		model.confirmRepair(failureID: id)
	}

	private var themeAnimation: Animation? {
		LauncherMotion.animation(.crossfade, reduceMotion: reduceMotion)
	}
}
