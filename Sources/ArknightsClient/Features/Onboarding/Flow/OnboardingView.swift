// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingView: View {
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

	let retryUpdateCheck: () -> Void

	var body: some View {
		HStack(spacing: 0) {
			OnboardingProgressRail(
				currentStep: coordinator.step,
				accentColor: customization.accentColor,
				appVersion: IssueReportURL.appVersion
			)

			Divider()
				.overlay(Color.white.opacity(0.08))

			ZStack(alignment: .bottom) {
				ScrollView {
					Group {
						switch coordinator.step {
						case .welcome:
							OnboardingWelcomeView(
								preferences: preferences,
								accentColor: customization.accentColor,
								updateState: coordinator.updateState,
								intelTranslationState: coordinator.intelTranslationState,
								rosettaInstallationState: lifecycle.rosettaInstallationState,
								retry: retryUpdateCheck,
								retryIntelTranslation: retryIntelTranslation,
								installRosetta: installRosetta
							)
						case .installation:
							OnboardingInstallationView(
								installation: installation,
								accentColor: customization.accentColor,
								canSwitchRegion: canSwitchRegion,
								selectRegion: actions.selectRegion
							)
						case .game:
							OnboardingGameSettingsView(
								preferences: preferences,
								accentColor: customization.accentColor
							)
						case .personalization:
							OnboardingPersonalizationView(
								customization: customization,
								preferences: preferences,
								resetArtwork: actions.resetArtwork,
								browseArtwork: { presentedGallery = .artwork }
							)
						case .icons:
							OnboardingIconsView(
								customization: customization,
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
				.id(coordinator.step)

				FloatingActionFooterFade(height: 76)

				FloatingActionBar(tint: customization.hudTintColor) {
					if coordinator.updateState.allowsSetup && coordinator.step != .finish {
						Button(action: coordinator.skip) {
							Label(
								L10n.string(OnboardingStrings.skipForNow),
								systemImage: "forward.end"
							)
						}
						.adaptiveNavigationCapsuleButton()
						.controlSize(.large)
					}
					Spacer()
					if coordinator.step != .welcome {
						Button(action: coordinator.goBack) {
							Label(
								L10n.string(OnboardingStrings.back),
								systemImage: "chevron.backward"
							)
						}
						.adaptiveNavigationCapsuleButton()
						.controlSize(.large)
					}
					CapsuleActionButton(
						title: L10n.string(primaryTitle),
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
		.animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: coordinator.step)
		.animation(
			reduceMotion ? nil : .easeInOut(duration: 0.3),
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

	private var primaryTitle: LocalizedStringResource {
		if coordinator.step == .welcome {
			return switch coordinator.updateState {
			case .checking: OnboardingStrings.checking
			case .current, .checkFailed:
				coordinator.intelTranslationState == .checking
					? OnboardingStrings.checking : OnboardingStrings.continue
			case .updateRequired(let version): OnboardingStrings.installUpdate(version)
			}
		}
		if coordinator.step == .installation {
			if installation.isInstalled || installation.isDownloading {
				return OnboardingStrings.continueSetup
			}
			return installation.hasPartialDownload
				? OnboardingStrings.resumeAndContinue : OnboardingStrings.installAndContinue
		}
		if coordinator.step == .finish { return OnboardingStrings.finishSetup }
		return OnboardingStrings.continue
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
		if coordinator.step == .installation {
			return installation.isInstalled || installation.isDownloading
				|| installation.canInstall
		}
		return true
	}

	private var primarySystemImage: String {
		if coordinator.step == .welcome, case .updateRequired = coordinator.updateState {
			return "arrow.down.app"
		}
		if coordinator.step == .installation && !installation.isInstalled
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
		if coordinator.step == .installation && !installation.isInstalled
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
