// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct ContentView: View {
	var model: LauncherViewModel
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
		_musicController = State(initialValue: BackgroundMusicController(model: model))
	}

	private var cyan: Color { model.accentColor }

	var body: some View {
		ZStack {
			BackgroundMusicView(model: model, controller: musicController)

			LauncherArtworkView(image: model.heroArtwork, accentColor: cyan)
				.ignoresSafeArea(.container, edges: .top)

			// Seamless top-left corner vignette for traffic lights & wordmark readability
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
		.animation(themeAnimation, value: model.dynamicThemeHue)
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
				accentColor: cyan,
				hudTintColor: model.hudTintColor,
				dismiss: model.dismissPopup,
				openAction: model.openPopupAction
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
			get: { onboarding.isPresented ? nil : model.popup },
			set: { popup in
				if popup == nil { model.dismissPopup() }
			}
		)
	}

	private var topBar: some View {
		HStack(alignment: .top) {
			ArknightsWordmark(logo: model.officialLogo, cyan: cyan)
				.padding(.top, 34)
			Spacer()
			Button("Settings", systemImage: "gearshape", action: presentSettings)
				.labelStyle(.iconOnly)
				.font(.system(size: 23, weight: .medium))
				.frame(width: 30, height: 30)
				.adaptiveGlassButton()
				.buttonBorderShape(.circle)
				.controlSize(.extraLarge)
				.keyboardShortcut(",", modifiers: .command)
				.help("Open launcher settings")
		}
		.padding(.top, 8)
		.padding(.horizontal, 14)
		.ignoresSafeArea(.container, edges: .top)
	}

	private func presentSettings() {
		settingsPresented = true
	}

	private func startOnboardingIfNeeded() async {
		model.updateInstalledState()
		await onboarding.startIfNeeded(
			isDeveloperMode: model.isDeveloperMode,
			isOnboardingPreview: model.isOnboardingPreview,
			gameIsInstalled: model.isInstalled,
			checkForUpdates: model.launcherUpdateCheckForOnboarding,
			checkIntelTranslation: { await model.refreshIntelTranslationAvailability() }
		)
	}

	private func retryOnboardingUpdateCheck() {
		Task {
			await onboarding.retryUpdateCheck(
				model.launcherUpdateCheckForOnboarding,
				checkIntelTranslation: { await model.refreshIntelTranslationAvailability() }
			)
		}
	}

	private func restartOnboarding() {
		settingsPresented = false
		model.updateInstalledState()
		Task {
			await onboarding.restart(
				gameIsInstalled: model.isInstalled,
				checkForUpdates: model.launcherUpdateCheckForOnboarding,
				checkIntelTranslation: { await model.refreshIntelTranslationAvailability() }
			)
		}
	}

	private func retryIntelTranslationCheck() {
		Task {
			await model.refreshIntelTranslationAvailability(force: true)
		}
	}

	private func installRosetta() {
		Task { await model.installRosetta() }
	}

	private var controlBar: some View {
		HStack(spacing: 16) {
			controlBarLeadingRegion
				.id(model.isDownloading ? "download-progress" : "launcher-status")
				.transition(.opacity)
				.frame(maxWidth: .infinity, alignment: .leading)

			HStack(spacing: 8) {
				if model.launcherUpdate != nil {
					CapsuleActionButton(
						"Launcher Update", systemImage: "arrow.down.app",
						tone: .accent(model.accentColor),
						action: model.openLauncherUpdate
					)
					.transition(.opacity)
					.help("Open the latest launcher release in your browser")
				}

				LauncherPrimaryActionView(model: model)
					.id(primaryActionIdentity)
					.transition(primaryActionTransition)
			}
		}
		.padding(16)
		.adaptiveGlassEffect(tint: model.hudTintColor, in: Capsule())
		.animation(stateAnimation, value: model.isDownloading)
		.animation(stateAnimation, value: primaryActionIdentity)
		.animation(stateAnimation, value: model.launcherUpdate != nil)
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
						MusicHUDPill(model: model, controller: musicController)
							.transition(hudPillTransition)
					}
					if hasVersionPill {
						VersionHUDPill(model: model)
							.transition(hudPillTransition)
					}
					if hasStatusPill {
						StatusHUDPill(model: model)
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
		model.showsPlayingMusic && model.currentMusicTitle != nil
	}

	private var hasVersionPill: Bool {
		model.showsGameVersion && model.versionText != "—"
	}

	private var hasStatusPill: Bool {
		model.resetCountdownText != nil
			|| model.installedRegions.count > 1
			|| model.region != .global
	}

	@ViewBuilder
	private var controlBarLeadingRegion: some View {
		if model.isDownloading {
			VStack(alignment: .leading, spacing: 7) {
				HStack(alignment: .firstTextBaseline, spacing: 10) {
					Text(statusTitle)
						.font(.system(size: 14, weight: .semibold))
						.contentTransition(.numericText())
					if let detail = statusDetail {
						Text(detail)
							.font(.caption)
							.foregroundStyle(.secondary)
							.lineLimit(1)
					}
				}

				ProgressView(value: model.progress?.fraction ?? 0)
					.progressViewStyle(.linear)
					.tint(cyan)
					.animation(.linear(duration: 0.2), value: model.progress?.fraction ?? 0)
			}
		} else {
			VStack(alignment: .leading, spacing: 2) {
				Text(statusTitle)
					.font(.system(size: 14, weight: .semibold))
					.contentTransition(.opacity)
				if let detail = statusDetail {
					Text(detail)
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(1)
					if isFailed {
						AccentActionLink(title: "Report Problem", accentColor: cyan) {
							NSWorkspace.shared.open(IssueReportURL.build(problem: detail))
						}
						.font(.caption)
					} else if model.isInstalled && model.canInstallRosetta {
						AccentActionLink(
							title: model.rosettaInstallationActionTitle,
							accentColor: cyan,
							action: { confirmsRosettaInstallation = true }
						)
						.font(.caption)
					} else if model.isInstalled && model.canRetryIntelTranslationCheck {
						AccentActionLink(
							title: "Check Again",
							accentColor: cyan,
							action: retryIntelTranslationCheck
						)
						.font(.caption)
					}
				}
			}
		}
	}

	private var statusTitle: String {
		if model.activityMessage == "Pausing…" {
			return model.activityMessage
		}
		if model.isDownloading, let progress = model.progress {
			return "\(Int(progress.fraction * 100))%"
		}
		if case .failed = model.phase { return "Needs attention" }
		if model.isInstalled, let title = model.intelTranslationStatusTitle { return title }
		return model.activityMessage
	}

	private var statusDetail: String? {
		if model.isDownloading, let progress = model.progress {
			let downloaded = ByteCountFormatter.string(
				fromByteCount: progress.downloadedBytes,
				countStyle: .file
			)
			let total = ByteCountFormatter.string(
				fromByteCount: progress.totalBytes, countStyle: .file)
			return "\(downloaded) of \(total)"
		}
		if case .failed(let message) = model.phase { return message }
		if model.isInstalled { return model.intelTranslationStatusDetail }
		return nil
	}

	private var isFailed: Bool {
		if case .failed = model.phase { return true }
		return false
	}

	private var primaryActionIdentity: String {
		if model.isGameRunning { return "stop" }
		if model.isDownloading { return "pause" }
		if !model.isInstalled { return model.hasPartialDownload ? "resume" : "install" }
		if model.isGameUpdateAvailable { return "update" }
		return "play"
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
