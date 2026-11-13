// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsCustomization
import ArknightsGameInstallation
import ArknightsGameRuntime
import SwiftUI

package struct OnboardingView: View {
	@Environment(\.launcherTheme) private var theme
	let preferences: LauncherPreferencesController
	let customization: CustomizationController
	let installation: InstallationController
	let runtimeSelection: RuntimeSelectionController
	let lifecycle: LauncherLifecycleStore
	let presetCatalog: PresetCatalogService
	let canSwitchRegion: Bool
	@Bindable var coordinator: OnboardingCoordinator
	let actions: OnboardingActions
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var presentedGallery: PresetGalleryDestination?
	@State private var isSkipConfirmationPresented = false
	@State private var scrollPosition = ScrollPosition(edge: .top)
	@State private var runtimeLane: RuntimeLane?
	@State private var pendingRuntimeLane: RuntimeLane?
	@State private var isRuntimeWarningPresented = false
	@State private var didInitializeRuntimeLane = false

	let retryUpdateCheck: () -> Void

	package init(
		preferences: LauncherPreferencesController,
		customization: CustomizationController,
		installation: InstallationController,
		runtimeSelection: RuntimeSelectionController,
		lifecycle: LauncherLifecycleStore,
		presetCatalog: PresetCatalogService,
		canSwitchRegion: Bool,
		coordinator: OnboardingCoordinator,
		actions: OnboardingActions,
		retryUpdateCheck: @escaping () -> Void
	) {
		self.preferences = preferences
		self.customization = customization
		self.installation = installation
		self.runtimeSelection = runtimeSelection
		self.lifecycle = lifecycle
		self.presetCatalog = presetCatalog
		self.canSwitchRegion = canSwitchRegion
		self.coordinator = coordinator
		self.actions = actions
		self.retryUpdateCheck = retryUpdateCheck
	}

	package var body: some View {
		HStack(spacing: 0) {
			OnboardingProgressRail(
				currentStep: coordinator.step,
				appVersion: IssueReportURL.appVersion,
				installation: installation,
				runtimeSelection: runtimeSelection,
				lifecycle: lifecycle,
				pauseDownload: actions.pauseDownload,
				pauseRuntime: actions.pauseRuntime,
				resumeRuntime: resumeRuntimeInstall,
				resumeDownload: actions.installOrUpdate,
				retryDownload: actions.installOrUpdate
			)

			Divider()
				.overlay(theme.hairline)

			ZStack(alignment: .bottom) {
				ScrollView {
					Group {
						switch coordinator.step {
						case .welcome:
							OnboardingWelcomeView(
								updateState: coordinator.updateState,
								requiredSchema: coordinator.requiredSchema,
								retry: retryUpdateCheck
							)
						case .region:
							OnboardingRegionView(
								preferences: preferences,
								installation: installation,
								canSwitchRegion: canSwitchRegion,
								selectRegion: actions.selectRegion
							)
						case .install:
							OnboardingInstallView(
								installation: installation,
								lifecycle: lifecycle,
								runtimeSelection: runtimeSelection,
								selectedLane: runtimeLaneBinding,
								isDisabled: runtimeSelection.isInstalling,
								intelTranslationState: coordinator.intelTranslationState,
								rosettaInstallationState: lifecycle.state.readiness
									.rosettaInstallation,
								chooseInstallDirectory: actions.chooseInstallDirectory,
								locateExistingInstallation: actions.locateExistingInstallation,
								retryIntelTranslation: retryIntelTranslation,
								installRosetta: installRosetta
							)
						case .display:
							OnboardingDisplayView(
								preferences: preferences,
								lifecycle: lifecycle
							)
						case .look:
							OnboardingLookView(
								customization: customization,
								preferences: preferences,
								resetArtwork: actions.resetArtwork,
								browseArtwork: { presentedGallery = .artwork },
								browseOperators: { presentedGallery = .operatorIcons }
							)
						case .extras:
							OnboardingExtrasView(
								preferences: preferences
							)
						case .finish:
							OnboardingFinishView(
								installation: installation,
								lifecycle: lifecycle,
								install: actions.installOrUpdate
							)
						}
					}
					.id(coordinator.step)
					.transition(stepTransition)
					.padding(.horizontal, LauncherTokens.Spacing.page)
					.padding(.top, LauncherTokens.Spacing.page)
					.padding(.bottom, 96)
				}
				.contentMargins(.top, LauncherTokens.Spacing.page, for: .scrollIndicators)
				.contentMargins(.bottom, LauncherTokens.Spacing.page, for: .scrollIndicators)
				.scrollIndicators(.automatic)
				.scrollPosition($scrollPosition)
				.onChange(of: coordinator.step) {
					scrollPosition.scrollTo(edge: .top)
					if coordinator.step == .install, !didInitializeRuntimeLane {
						runtimeLane = runtimeSelection.selectedLane
						didInitializeRuntimeLane = true
					}
				}

				FloatingActionFooterFade(height: 76)

				FloatingActionBar {
					if coordinator.updateState.allowsSetup && coordinator.requiredSchema == nil
						&& coordinator.step != .finish
					{
						CapsuleActionButton(
							title: "Skip Setup",
							systemImage: "forward.end",
							tone: .neutral
						) {
							isSkipConfirmationPresented = true
						}
						.controlSize(.large)
						.alert(
							"Skip setup?",
							isPresented: $isSkipConfirmationPresented
						) {
							Button("Cancel", role: .cancel) {}
								.keyboardShortcut(.defaultAction)
							Button("Skip Anyway") {
								coordinator.skip()
							}
						} message: {
							Text(
								"Setup picks your server, how the game looks on your screen, and how the launcher behaves. You can run it again from Settings → Help → Troubleshooting."
							)
						}
					}
					Spacer()
					if coordinator.step != .welcome {
						CapsuleActionButton(
							title: "Back",
							systemImage: "chevron.backward",
							tone: .neutral,
							action: coordinator.goBack
						)
						.controlSize(.large)
					}
					CapsuleActionButton(
						title: primaryTitle,
						systemImage: primarySystemImage,
						tone: .accent,
						action: performPrimaryAction
					)
					.controlSize(.large)
					.disabled(!canPerformPrimaryAction)
					.keyboardShortcut(.defaultAction)
				}
				.padding(.horizontal, LauncherTokens.Spacing.page)
				.padding(.bottom, LauncherTokens.Spacing.panel)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background {
			theme.sheetSolid
				.ignoresSafeArea(.container, edges: .top)
		}
		.tint(theme.accentFill)
		.animation(
			LauncherMotion.animation(for: .present, reduceMotion: reduceMotion),
			value: coordinator.step
		)
		.animation(
			LauncherMotion.animation(.crossfade, reduceMotion: reduceMotion),
			value: customization.dynamicThemeHue
		)
		.sheet(item: $presentedGallery) { destination in
			PresetGalleryView(
				catalog: presetCatalog,
				customization: customization,
				lifecycle: lifecycle,
				destination: destination
			)
		}
		.onAppear {
			if !didInitializeRuntimeLane {
				runtimeLane = runtimeSelection.selectedLane
				didInitializeRuntimeLane = true
			}
		}
		.confirmationDialog(
			runtimeWarningTitle,
			isPresented: $isRuntimeWarningPresented,
			titleVisibility: .visible
		) {
			Button(runtimeWarningButtonTitle) {
				if let pendingRuntimeLane { runtimeLane = pendingRuntimeLane }
				pendingRuntimeLane = nil
				runtimeSelection.clearFailure()
			}
			Button("Cancel", role: .cancel) { pendingRuntimeLane = nil }
		} message: {
			Text(runtimeWarningMessage)
		}
	}

	// The new page enters from the side it travels toward and the old page fades out. SwiftUI reads
	// a leaving view's transition from its last render, so only the entering page can follow the
	// direction. Reduce Motion keeps the fade alone.
	private var stepTransition: AnyTransition {
		guard !reduceMotion else { return .opacity }
		let edge: Edge = coordinator.direction == .forward ? .trailing : .leading
		return .asymmetric(
			insertion: .move(edge: edge).combined(with: .opacity),
			removal: .opacity
		)
	}

	private var primaryTitle: String {
		if coordinator.step == .welcome {
			return switch coordinator.updateState {
			case .checking: OnboardingUpdateState.checkingTitle
			case .current, .checkFailed: "Continue"
			case .updateRequired(let version): "Install Update \(version)"
			}
		}
		if coordinator.step == .install { return installPlan.primaryTitle }
		if coordinator.step == .finish { return "Finish Setup" }
		return "Continue"
	}

	private var canPerformPrimaryAction: Bool {
		if coordinator.step == .welcome {
			switch coordinator.updateState {
			case .checking:
				return false
			case .updateRequired:
				return true
			case .current, .checkFailed:
				return true
			}
		}
		if coordinator.step == .install { return canInstall }
		return true
	}

	private var primarySystemImage: String {
		if coordinator.step == .welcome, case .updateRequired = coordinator.updateState {
			return "arrow.down.app"
		}
		if coordinator.step == .install, installPlan.needsDownload {
			return installation.hasPartialDownload && !installPlan.runtimeNeedsDownload
				? "arrow.clockwise" : "arrow.down"
		}
		if coordinator.step == .finish { return "checkmark" }
		return "chevron.forward"
	}

	private func performPrimaryAction() {
		if coordinator.step == .welcome,
			case .updateRequired = coordinator.updateState
		{
			actions.openLauncherUpdate()
			return
		}
		if coordinator.step == .install {
			performInstallAction()
			return
		}
		coordinator.advance()
	}

	// The game download and runtime install start here and nowhere else. A complete install
	// downloads nothing, so a setup rerun only confirms what is already there.
	private var installPlan: OnboardingInstallPlan {
		OnboardingInstallPlan(
			gameIsInstalled: installation.isInstalled,
			gameIsDownloading: installation.isDownloading,
			runtimeIsInstalled: runtimeLane.map {
				runtimeSelection.installedVersion(for: $0) != nil
			} ?? false
		)
	}

	private var canInstall: Bool {
		guard !runtimeSelection.isInstalling, !coordinator.installRunner.isRunning,
			let runtimeLane,
			runtimeSelection.availableLanes.contains(runtimeLane)
		else { return false }
		if runtimeLane == .x86 {
			switch coordinator.intelTranslationState {
			case .checking, .waitingForLauncherCheck: return false
			default: break
			}
		}
		let plan = installPlan
		if plan.gameNeedsDownload && !installation.canInstall { return false }
		if plan.runtimeNeedsDownload {
			return lifecycle.activity == .idle || lifecycle.activity.isInstalling
		}
		return runtimeLane == runtimeSelection.selectedLane || lifecycle.activity == .idle
	}

	// Resuming re-runs the install; the installer continues from its partial archive.
	private func resumeRuntimeInstall() {
		guard let lane = runtimeSelection.pausedLane else { return }
		coordinator.installRunner.installRuntime(
			lane,
			startsGameDownload: false,
			actions: actions
		) { [coordinator] in
			guard coordinator.step == .install else { return }
			coordinator.advance()
		}
	}

	private func performInstallAction() {
		guard let runtimeLane else { return }
		let plan = installPlan
		if plan.runtimeNeedsDownload {
			coordinator.installRunner.installRuntime(
				runtimeLane,
				startsGameDownload: plan.gameNeedsDownload,
				actions: actions
			) { [coordinator] in
				guard coordinator.step == .install else { return }
				coordinator.advance()
			}
			return
		}
		if runtimeLane != runtimeSelection.selectedLane {
			guard actions.selectRuntimeLane(runtimeLane) else { return }
		}
		if plan.gameNeedsDownload { actions.installOrUpdate() }
		coordinator.advance()
	}

	private var runtimeLaneBinding: Binding<RuntimeLane?> {
		Binding(
			get: { runtimeLane },
			set: { newLane in
				guard let newLane, newLane != runtimeLane else { return }
				if runtimeSelection.switchRequiresWarning,
					newLane == .arm || runtimeLane == .arm
				{
					pendingRuntimeLane = newLane
					isRuntimeWarningPresented = true
				} else {
					runtimeLane = newLane
					runtimeSelection.clearFailure()
				}
			}
		)
	}

	private var runtimeWarningTitle: String {
		runtimeWarningLane == .arm ? "Switch to ARM64?" : "Switch to x86_64?"
	}

	private var runtimeWarningButtonTitle: String {
		runtimeWarningLane == .arm ? "Use ARM64" : "Use x86_64"
	}

	private var runtimeWarningLane: RuntimeLane {
		pendingRuntimeLane ?? runtimeLane ?? .x86
	}

	private var runtimeWarningMessage: String {
		let lane = runtimeWarningLane
		guard let pin = runtimeSelection.pinnedRuntime(for: lane) else {
			return RuntimeSwitchWarning.message
		}
		return RuntimeSwitchWarning.message(
			for: pin,
			isInstalled: runtimeSelection.installedVersion(for: lane) != nil
		)
	}

	private func retryIntelTranslation() {
		Task {
			await coordinator.refreshIntelTranslationAvailability {
				await actions.retryIntelTranslation()
			}
		}
	}

	private func installRosetta() {
		Task {
			let state = await actions.installRosetta()
			await coordinator.refreshIntelTranslationAvailability { state }
		}
	}
}
