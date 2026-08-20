// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingView: View {
	@Bindable var model: LauncherViewModel
	@Bindable var coordinator: OnboardingCoordinator
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var presentedGallery: PresetGalleryDestination?

	let retryUpdateCheck: () -> Void

	var body: some View {
		HStack(spacing: 0) {
			OnboardingProgressRail(
				currentStep: coordinator.step,
				accentColor: model.accentColor,
				appVersion: model.appVersion
			)

			Divider()
				.overlay(Color.white.opacity(0.08))

			ZStack(alignment: .bottom) {
				ScrollView {
					Group {
						switch coordinator.step {
						case .welcome:
							OnboardingWelcomeView(
								updateState: coordinator.updateState,
								rosettaState: coordinator.rosettaState,
								accentColor: model.accentColor,
								retry: retryUpdateCheck,
								retryRosetta: { coordinator.refreshRosettaAvailability() }
							)
						case .installation:
							OnboardingInstallationView(model: model)
						case .game:
							OnboardingGameSettingsView(model: model)
						case .personalization:
							OnboardingPersonalizationView(
								model: model,
								browseArtwork: { presentedGallery = .artwork }
							)
						case .icons:
							OnboardingIconsView(
								model: model,
								browseLauncherOperators: { presentedGallery = .launcherIcon },
								browseGameOperators: { presentedGallery = .gameIcon }
							)
						case .extras:
							OnboardingExtrasView(model: model)
						case .finish:
							OnboardingFinishView(model: model)
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

				LinearGradient(
					colors: [.clear, Color.black.opacity(0.45)],
					startPoint: .top,
					endPoint: .bottom
				)
				.frame(height: 76)
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
				.allowsHitTesting(false)

				HStack(spacing: 12) {
					if coordinator.updateState.allowsSetup && coordinator.step != .finish {
						Button(action: coordinator.skip) {
							Label("Skip for Now", systemImage: "forward.end")
								.foregroundStyle(.primary)
						}
						.adaptiveGlassCapsuleButton()
						.controlSize(.large)
						.tint(SettingsVisuals.controlTint)
					}
					Spacer()
					if coordinator.step != .welcome {
						Button(action: coordinator.goBack) {
							Label("Back", systemImage: "chevron.backward")
								.foregroundStyle(.primary)
						}
						.adaptiveGlassCapsuleButton()
						.controlSize(.large)
						.tint(SettingsVisuals.controlTint)
					}
					Button(action: performPrimaryAction) {
						HStack(spacing: 6) {
							Text(primaryTitle)
							Image(systemName: primarySystemImage)
								.accessibilityHidden(true)
						}
						.foregroundStyle(model.accentTextColor)
					}
					.adaptiveGlassCapsuleButton(prominent: true)
					.controlSize(.large)
					.tint(model.accentColor)
					.disabled(!canPerformPrimaryAction)
					.keyboardShortcut(.defaultAction)
				}
				.padding(10)
				.adaptiveGlassEffect(tint: model.hudTintColor, in: Capsule())
				.padding(.horizontal, 24)
				.padding(.bottom, 18)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background {
			ZStack {
				Color(red: 0.07, green: 0.07, blue: 0.08)
				model.hudTintColor
			}
			.ignoresSafeArea(.container, edges: .top)
		}
		.tint(model.accentColor)
		.preferredColorScheme(.dark)
		.animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: coordinator.step)
		.animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: model.dynamicThemeHue)
		.sheet(item: $presentedGallery) { destination in
			PresetGalleryView(model: model, destination: destination)
		}
	}

	private var primaryTitle: String {
		if coordinator.step == .welcome {
			return switch coordinator.updateState {
			case .checking: "Checking…"
			case .current, .checkFailed: "Continue"
			case .updateRequired(let release): "View Version \(release.version)"
			}
		}
		if coordinator.step == .installation {
			if model.isInstalled || model.isDownloading { return "Continue Setup" }
			return model.hasPartialDownload ? "Resume & Continue" : "Install & Continue"
		}
		if coordinator.step == .finish { return "Finish Setup" }
		return "Continue"
	}

	private var canPerformPrimaryAction: Bool {
		if coordinator.step == .welcome {
			if case .checking = coordinator.updateState { return false }
			return true
		}
		if coordinator.step == .installation {
			return model.isInstalled || model.isDownloading || model.canInstall
		}
		return true
	}

	private var primarySystemImage: String {
		if coordinator.step == .welcome, case .updateRequired = coordinator.updateState {
			return "arrow.up.right"
		}
		if coordinator.step == .installation && !model.isInstalled && !model.isDownloading {
			return model.hasPartialDownload ? "arrow.clockwise" : "arrow.down"
		}
		if coordinator.step == .finish { return "checkmark" }
		return "chevron.forward"
	}

	private func performPrimaryAction() {
		if coordinator.step == .welcome,
			case .updateRequired = coordinator.updateState
		{
			model.openLauncherUpdate()
			return
		}
		if coordinator.step == .installation && !model.isInstalled && !model.isDownloading {
			model.installOrUpdate()
		}
		coordinator.advance()
	}
}
