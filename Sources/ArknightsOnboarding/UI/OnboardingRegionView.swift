// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

struct OnboardingRegionView: View {
	@Bindable var preferences: LauncherPreferencesController
	@Bindable var installation: InstallationController
	let lifecycle: LauncherLifecycleStore
	let accentColor: Color
	let canSwitchRegion: Bool
	package let selectRegion: @MainActor @Sendable (GameRegion) -> Void

	var body: some View {
		OnboardingPage(
			title: "Your server",
			subtitle:
				"Each server has its own game files and accounts. Pick the one you already play on; you can add another later in Settings.",
			accentColor: accentColor
		) {
			OnboardingQuestion(
				question: "Which server do you play on?",
				systemImage: "globe.asia.australia",
				answers: preferences.regionAccess.selectableRegions.map(
					OnboardingStrings.regionAnswer),
				selection: regionBinding,
				accentColor: accentColor,
				isDisabled: !canSwitchRegion
			)

			OnboardingCanaryPanel(title: "Canary Features") {
				OnboardingToggleRow(
					title: "Canary Features",
					detail:
						"Turns on experimental features and unlocks more servers. Turning it off switches a Canary server back to Global.",
					isOn: $preferences.canaryFeaturesEnabled,
					accentColor: LauncherVisuals.warning
				)
				.disabled(lifecycle.activity != .idle)
				if preferences.canaryFeaturesEnabled {
					OnboardingToggleRow(
						title: "Allow Taiwan client",
						detail: "Lets you pick the Taiwan server.",
						isOn: $preferences.taiwanClientEnabled,
						accentColor: LauncherVisuals.warning
					)
					.disabled(lifecycle.activity != .idle)
				}
			}

			SettingsPanel(title: "Game files", systemImage: installationImage) {
				HStack {
					VStack(alignment: .leading, spacing: 4) {
						if isLoadingInstallationMetadata {
							SkeletonValue(width: 160, height: 17, pulses: true)
							SkeletonValue(width: 216, height: 15, pulses: true)
						} else {
							Text(installationTitle)
								.bold()
							Text(installationDetail)
								.font(.callout)
								.foregroundStyle(.secondary)
						}
					}
					Spacer()
					if installation.lifecycle.state.refresh.isChecking {
						ProgressView()
					} else if installation.isInstalled && !installation.isDownloading {
						Image(systemName: "checkmark.circle.fill")
							.foregroundStyle(accentColor)
							.accessibilityHidden(true)
					}
				}

				if installation.isDownloading, let progress = installation.progress {
					ProgressView(value: progress.fraction)
						.tint(accentColor)
						.accessibilityLabel(Text(installationTitle))
					Text(
						"\(DownloadProgressFormatting.byteCount(progress.downloadedBytes)) of \(DownloadProgressFormatting.byteCount(progress.totalBytes))"
					)
					.font(.caption.monospacedDigit())
					.foregroundStyle(.secondary)
				}

				if !installation.isInstalled && !installation.isDownloading {
					Text("Continue to start the download. Closing the launcher pauses it safely.")
						.font(.callout)
						.foregroundStyle(.secondary)
				}
			}
		}
	}

	private var installationImage: String {
		if installation.isDownloading {
			return isVerifying ? "checkmark.shield" : "arrow.down.circle"
		}
		if installation.isInstalled { return "checkmark.circle" }
		return "externaldrive.badge.plus"
	}

	private var installationTitle: String {
		if installation.isDownloading { return lifecycle.state.presentation.status.message }
		if installation.isInstalled { return "Game already installed" }
		if installation.hasPartialDownload { return "Download paused" }
		return "Ready to install \(installation.region.displayName)"
	}

	private var installationDetail: String {
		if installation.isDownloading {
			return isVerifying
				? "You can keep going while the game files are checked."
				: "You can keep going while the game downloads."
		}
		if installation.isInstalled {
			let version =
				installation.installedVersion ?? installation.configuration?.gameLatestVersion
				?? "—"
			return
				"Arknights \(version) is ready in \(installation.installDirectory.lastPathComponent)."
		}
		if installation.hasPartialDownload {
			return "Setup continues from where the download stopped."
		}
		return "Needs about \(installationSize) of space once installed."
	}

	private var isVerifying: Bool {
		lifecycle.state.presentation.status == .verifyingInstallation
			|| installation.progress?.isVerifying == true
	}

	private var isLoadingInstallationMetadata: Bool {
		installation.lifecycle.state.refresh.isChecking
			&& installation.configuration == nil
			&& !installation.isInstalled
			&& !installation.hasPartialDownload
			&& !installation.isDownloading
	}

	private var installationSize: String {
		guard let configuration = installation.configuration else { return "—" }
		if let requiredInstallBytes = configuration.requiredInstallBytes {
			return DownloadProgressFormatting.byteCount(requiredInstallBytes)
		}
		return configuration.decompressionSize
	}

	private var regionBinding: Binding<GameRegion?> {
		Binding(
			get: { installation.region },
			set: { region in
				if let region { selectRegion(region) }
			}
		)
	}
}
