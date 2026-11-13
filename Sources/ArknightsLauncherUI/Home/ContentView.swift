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
	/// Runs a queued sheet promotion after the current run loop turn. SwiftUI must finish
	/// dismissing the previous sheet before the presentation item becomes non-nil again.
	let scheduleSheetPromotion: @MainActor (@escaping @MainActor () -> Void) -> Void
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
	@State var presentation = LauncherPresentationArbiter()
	@State var confirmation: LauncherConfirmation?
	@State var repairFailureID: UUID?
	@State var decorativeMotionVisibility = DecorativeMotionVisibility()
	@State private var isTerminating = false
	@State var windowSize = CGSize.zero
	@State var settingsSection = SettingsSection.initial

	package init(
		model: LauncherViewModel,
		musicController: BackgroundMusicController,
		onboarding: OnboardingCoordinator,
		registerOpenSettings: @escaping (@escaping () -> Void) -> Void,
		registerQuitPresentationQuery:
			@escaping (@escaping () -> LauncherPresentationDestination?) -> Void,
		registerQuitDismissal: @escaping (@escaping () -> Void) -> Void,
		scheduleSheetPromotion: @escaping @MainActor (@escaping @MainActor () -> Void) -> Void = {
			promotion in
			Task { @MainActor in promotion() }
		}
	) {
		self.model = model
		self.musicController = musicController
		self.onboarding = onboarding
		self.registerOpenSettings = registerOpenSettings
		self.registerQuitPresentationQuery = registerQuitPresentationQuery
		self.registerQuitDismissal = registerQuitDismissal
		self.scheduleSheetPromotion = scheduleSheetPromotion
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
			LauncherReadabilityField(showsBranding: model.settings.showsBranding)
				.environment(\.colorScheme, brandingColorScheme)
				.ignoresSafeArea(.container, edges: .top)
				.allowsHitTesting(false)
			VStack(spacing: 0) {
				topBar
				Spacer()
				LauncherHUDView(
					lifecycle: model.lifecycle,
					settings: model.settings,
					installation: model.installation,
					gameSession: model.gameSession,
					runtimeSelection: model.runtimeSelection,
					intelTranslation: model.intelTranslation,
					communication: model.communication,
					canSwitchRegion: model.refreshController.canSwitchRegion,
					accentColor: model.customization.accentColor,
					homeColorScheme: homeColorScheme,
					musicController: musicController,
					actions: LauncherHUDActions(
						openLauncherUpdate: requestLauncherUpdateCheck,
						checkGameUpdates: { model.actions.checkGameUpdates() },
						selectRegion: { model.actions.selectRegion($0) },
						installOrUpdate: { model.actions.installOrUpdate() },
						cancelDownload: { model.actions.cancelDownload() },
						installRuntime: { model.installSelectedRuntime() },
						launch: { model.actions.launch() },
						stopGame: { model.actions.stopGame() },
						showFailureDetails: showFailureDetails
					),
					developerExpandedPill: developerExpandedPill
				)
			}
			.environment(\.decorativeMotionEnabled, homeLayerMotionEnabled)
		}
		.disabled(updateOverlayIsPresented)
		.allowsHitTesting(!updateOverlayIsPresented)
		.accessibilityHidden(updateOverlayIsPresented)
		.background(LauncherVisuals.opaqueDim)
		// Home artwork stays dark. The wordmark and its scrim follow brandingColorScheme; the HUD
		// pills and the settings button follow homeColorScheme.
		// Sheets and overlays attach outside this container.
		.launcherTheme(accent: model.customization.accentColor)
		.environment(\.colorScheme, .dark)
		.background {
			WindowVisibilityReader(visibility: decorativeMotionVisibility)
		}
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
					runtimeSelection: model.runtimeSelection,
					lifecycle: model.lifecycle,
					presetCatalog: model.presetCatalog,
					canSwitchRegion: model.refreshController.canSwitchRegion,
					coordinator: onboarding,
					actions: OnboardingActions(
						selectRegion: { model.actions.selectRegion($0) },
						resetArtwork: { model.actions.resetArtwork() },
						installOrUpdate: { model.actions.installOrUpdate() },
						pauseDownload: { model.actions.cancelDownload() },
						chooseInstallDirectory: { model.actions.chooseInstallDirectory() },
						locateExistingInstallation: { model.actions.locateExistingInstallation() },
						installRuntime: { lane in await model.actions.installRuntime(lane) },
						pauseRuntime: { model.actions.pauseRuntimeDownload() },
						selectRuntimeLane: { lane in model.actions.selectRuntimeLane(lane) },
						openLauncherUpdate: { model.actions.openLauncherUpdate() },
						retryIntelTranslation: {
							await model.actions.refreshIntelTranslationForUI(force: true)
						},
						installRosetta: { await model.actions.installRosetta() }),
					retryUpdateCheck: retryOnboardingUpdateCheck
				)
				.launcherTheme(accent: model.customization.accentColor)
			}
		}
		// Artwork layers ignore the top safe area and inflate `size`; the sheet fits inside it.
		.onGeometryChange(for: CGSize.self) { proxy in
			let insets = proxy.safeAreaInsets
			return CGSize(
				width: proxy.size.width - insets.leading - insets.trailing,
				height: proxy.size.height - insets.top - insets.bottom)
		} action: {
			windowSize = $0
		}
		.environment(\.launcherWindowSize, windowSize)
		.sheet(item: sheetPresentation, onDismiss: presentationDidDismiss) {
			sheetContent(for: $0)
				.launcherTheme(accent: model.customization.accentColor)
		}
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

			.launcherTheme(accent: model.customization.accentColor)
	}

	// Split out of `body`: the full modifier chain exceeds the type checker's budget.
	@ViewBuilder
	private var updateOverlay: some View {
		if updateOverlayIsPresented {
			LauncherUpdateOverlay(
				driver: model.communication.launcherUpdateUserDriver,
				reduceTransparency: reduceTransparency,
				checkForUpdates: { model.actions.openLauncherUpdate() }
			)
			.launcherTheme(accent: model.customization.accentColor)
		}
	}

	@ViewBuilder
	private var initialArtworkCover: some View {
		if !model.customization.hasCompletedInitialArtworkLoad {
			LauncherVisuals.opaqueDim.ignoresSafeArea()
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

	private var homeColorScheme: ColorScheme {
		model.customization.homeColorScheme(for: model.settings.homeTheme)
	}

	private var brandingColorScheme: ColorScheme {
		switch model.settings.brandingTheme {
		case .automatic: homeColorScheme
		case .dark: .dark
		case .light: .light
		}
	}

	private var topBar: some View {
		HStack(alignment: .top) {
			if model.settings.showsBranding {
				ArknightsWordmark(
					logo: model.customization.officialLogo, region: model.installation.region
				).padding(.top, 32)
					.environment(\.colorScheme, brandingColorScheme)
					.launcherAnimation(.state, value: brandingColorScheme)
			}
			Spacer()
			IconActionButton(
				title: "Settings",
				systemImage: "gearshape",
				tone: .neutral,
				foreground: .primary,
				surface: .hud,
				size: 40,
				hitTargetSize: 44,
				action: requestSettings
			)
			.frame(minWidth: 44, minHeight: 44)
			.keyboardShortcut(",", modifiers: .command)
			.accessibilityHint(Text("Open launcher settings"))
			.help("Open launcher settings")
			.launcherTheme(accent: model.customization.accentColor)
			.environment(\.colorScheme, homeColorScheme)
			.launcherAnimation(.state, value: homeColorScheme)
		}
		.padding(.top, LauncherTokens.Spacing.control)
		.padding(.horizontal, LauncherTokens.Spacing.panel)
		.ignoresSafeArea(.container, edges: .top)
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
	func requestLauncherUpdateCheck() {
		let hadCurrentPresentation = presentation.current != nil
		presentation.request(.update)
		if !hadCurrentPresentation, presentation.current == .update {
			model.actions.openLauncherUpdate()
		}
	}
	private func presentationDidDismiss() {
		// Presenting from inside SwiftUI's own dismissal callback leaves the new sheet detached,
		// so promote the queued destination only after this run loop turn.
		scheduleSheetPromotion {
			presentation.didDismiss()
			if presentation.current == .update { model.actions.openLauncherUpdate() }
		}
	}
	private func launcherUpdateDidDismiss() {
		presentation.didDismiss(.update)
		if presentation.current == .update { model.actions.openLauncherUpdate() }
	}
	private func presentFailure(_ failure: LauncherFailurePresentation?) {
		if presentation.suppressesFailure(failure, isOnboardingPresented: onboarding.isPresented) {
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
		guard await model.waitForStartup(), model.canStartOnboarding else { return }
		if model.onboardingShouldRefreshInstalledState {
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
	func restartOnboarding() {
		guard model.lifecycle.activity != .maintaining(.migratingStorage) else { return }
		presentation.dismissCurrent()
		Task {
			if model.onboardingShouldRefreshInstalledState {
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
	func failureDetailsDidDismiss() {
		guard repairFailureID == nil,
			let failure = model.lifecycle.state.presentation.failure,
			!presentation.presents(.failure(failure))
		else { return }
		if !failure.blocksGameLaunch {
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
