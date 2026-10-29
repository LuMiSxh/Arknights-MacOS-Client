// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsCustomization
import ArknightsGameInstallation
import SwiftUI

package struct OnboardingView: View {
	let preferences: LauncherPreferencesController
	let customization: CustomizationController
	let installation: InstallationController
	let lifecycle: LauncherLifecycleStore
	let presetCatalog: PresetCatalogService
	let canSwitchRegion: Bool
	@Bindable var coordinator: OnboardingCoordinator
	let actions: OnboardingActions
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var presentedGallery: PresetGalleryDestination?
	@State private var isSkipConfirmationPresented = false
	@State private var scrollPosition = ScrollPosition(edge: .top)

	let retryUpdateCheck: () -> Void

	package init(
		preferences: LauncherPreferencesController,
		customization: CustomizationController,
		installation: InstallationController,
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
				accentColor: customization.accentColor,
				appVersion: IssueReportURL.appVersion
			)

			Divider()
				.overlay(LauncherVisuals.hairline)

			ZStack(alignment: .bottom) {
				ScrollView {
					Group {
						switch coordinator.step {
						case .welcome:
							OnboardingWelcomeView(
								accentColor: customization.accentColor,
								updateState: coordinator.updateState,
								intelTranslationState: coordinator.intelTranslationState,
								requiredSchema: coordinator.requiredSchema,
								rosettaInstallationState: lifecycle.state.readiness
									.rosettaInstallation,
								retry: retryUpdateCheck,
								retryIntelTranslation: retryIntelTranslation,
								installRosetta: installRosetta
							)
						case .region:
							OnboardingRegionView(
								preferences: preferences,
								installation: installation,
								lifecycle: lifecycle,
								accentColor: customization.accentColor,
								canSwitchRegion: canSwitchRegion,
								selectRegion: actions.selectRegion
							)
						case .display:
							OnboardingDisplayView(
								preferences: preferences,
								lifecycle: lifecycle,
								accentColor: customization.accentColor
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
								preferences: preferences,
								accentColor: customization.accentColor
							)
						case .finish:
							OnboardingFinishView(
								installation: installation,
								lifecycle: lifecycle,
								accentColor: customization.accentColor,
								install: actions.installOrUpdate
							)
						}
					}
					.id(coordinator.step)
					.transition(
						reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity)
					)
					.padding(.horizontal, 26)
					.padding(.top, 26)
					.padding(.bottom, 96)
				}
				.contentMargins(.top, 14, for: .scrollIndicators)
				.contentMargins(.bottom, 22, for: .scrollIndicators)
				.scrollIndicators(.automatic)
				.scrollPosition($scrollPosition)
				.onChange(of: coordinator.step) {
					scrollPosition.scrollTo(edge: .top)
				}

				FloatingActionFooterFade(height: 76)

				FloatingActionBar(tint: customization.hudTintColor) {
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
							Button("Continue Setup", role: .cancel) {}
								.keyboardShortcut(.defaultAction)
							Button("Skip Anyway", role: .destructive) {
								coordinator.skip()
							}
						} message: {
							Text(
								"Setup picks your server, how the game looks on your screen, and how the launcher behaves. You can run it again from Settings → Help."
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
						tone: .accent(customization.accentColor),
						action: performPrimaryAction
					)
					.controlSize(.large)
					.disabled(!canPerformPrimaryAction)
					.keyboardShortcut(.defaultAction)
				}
				.padding(.horizontal, 24)
				.padding(.bottom, 18)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background {
			ZStack {
				LauncherVisuals.modalBackground
				customization.hudTintColor
			}
			.ignoresSafeArea(.container, edges: .top)
		}
		.tint(customization.accentColor)
		.preferredColorScheme(.dark)
		.animation(
			LauncherMotion.animation(.page, reduceMotion: reduceMotion),
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
	}

	private var primaryTitle: String {
		if coordinator.step == .welcome {
			return switch coordinator.updateState {
			case .checking: OnboardingUpdateState.checkingTitle
			case .current, .checkFailed:
				coordinator.intelTranslationState == .checking
					? OnboardingUpdateState.checkingTitle : "Continue"
			case .updateRequired(let version): "Install Update \(version)"
			}
		}
		if coordinator.step == .region {
			if installation.isInstalled || installation.isDownloading {
				return "Continue Setup"
			}
			return installation.hasPartialDownload
				? "Resume & Continue" : "Install & Continue"
		}
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
				return coordinator.intelTranslationState != .checking
					&& coordinator.intelTranslationState != .waitingForLauncherCheck
			}
		}
		if coordinator.step == .region {
			return installation.isInstalled || installation.isDownloading
				|| installation.canInstall
		}
		return true
	}

	private var primarySystemImage: String {
		if coordinator.step == .welcome, case .updateRequired = coordinator.updateState {
			return "arrow.down.app"
		}
		if coordinator.step == .region && !installation.isInstalled
			&& !installation.isDownloading
		{
			return installation.hasPartialDownload ? "arrow.clockwise" : "arrow.down"
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
		if coordinator.step == .region && !installation.isInstalled
			&& !installation.isDownloading
		{
			actions.installOrUpdate()
		}
		coordinator.advance()
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
