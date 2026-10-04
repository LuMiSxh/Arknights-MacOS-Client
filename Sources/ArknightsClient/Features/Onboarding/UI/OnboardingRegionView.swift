// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingRegionView: View {
	@Bindable var preferences: LauncherPreferencesController
	@Bindable var installation: InstallationController
	let lifecycle: LauncherLifecycleStore
	let accentColor: Color
	let canSwitchRegion: Bool
	let selectRegion: @MainActor @Sendable (GameRegion) -> Void

	var body: some View {
		OnboardingPage(
			title: OnboardingStrings.regionTitle,
			subtitle: OnboardingStrings.regionSubtitle,
			accentColor: accentColor
		) {
			OnboardingQuestion(
				question: OnboardingStrings.regionQuestion,
				systemImage: "globe.asia.australia",
				answers: preferences.regionAccess.selectableRegions.map(
					OnboardingStrings.regionAnswer),
				selection: regionBinding,
				accentColor: accentColor,
				isDisabled: !canSwitchRegion
			)

			OnboardingCanaryPanel(title: OnboardingStrings.canaryFeatures) {
				OnboardingToggleRow(
					title: OnboardingStrings.canaryFeatures,
					detail: OnboardingStrings.canaryFeaturesDetail,
					isOn: $preferences.canaryFeaturesEnabled,
					accentColor: LauncherVisuals.warning
				)
				.disabled(lifecycle.activity != .idle)
				if preferences.canaryFeaturesEnabled {
					OnboardingToggleRow(
						title: OnboardingStrings.chinaClients,
						detail: OnboardingStrings.chinaClientsDetail,
						isOn: $preferences.chinaClientsEnabled,
						accentColor: LauncherVisuals.warning
					)
					.disabled(lifecycle.activity != .idle)
					OnboardingToggleRow(
						title: OnboardingStrings.taiwanClient,
						detail: OnboardingStrings.taiwanClientDetail,
						isOn: $preferences.taiwanClientEnabled,
						accentColor: LauncherVisuals.warning
					)
					.disabled(lifecycle.activity != .idle)
				}
			}

			SettingsPanel(title: OnboardingStrings.gameFiles, systemImage: installationImage) {
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
					if installation.lifecycle.refresh.isChecking {
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
					Text(OnboardingStrings.installDownloadDetail)
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
		if installation.isDownloading { return lifecycle.activityMessage }
		if installation.isInstalled { return OnboardingStrings.existingTitle }
		if installation.hasPartialDownload { return OnboardingStrings.partialTitle }
		return OnboardingStrings.readyToInstall(installation.region.displayName)
	}

	private var installationDetail: String {
		if installation.isDownloading {
			return isVerifying
				? OnboardingStrings.verifyingDetail : OnboardingStrings.downloadingDetail
		}
		if installation.isInstalled {
			return OnboardingStrings.installationExisting(
				version: installation.installedVersion
					?? installation.configuration?.gameLatestVersion ?? "—",
				directory: installation.installDirectory.lastPathComponent
			)
		}
		if installation.hasPartialDownload { return OnboardingStrings.partialDetail }
		return OnboardingStrings.installationSize(installationSize)
	}

	private var isVerifying: Bool {
		lifecycle.presentation.status == .verifyingInstallation
			|| installation.progress?.isVerifying == true
	}

	private var isLoadingInstallationMetadata: Bool {
		installation.lifecycle.refresh.isChecking
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
