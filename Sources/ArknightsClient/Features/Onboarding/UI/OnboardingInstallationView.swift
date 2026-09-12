// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingInstallationView: View {
	@Bindable var preferences: LauncherPreferencesController
	@Bindable var installation: InstallationController
	let lifecycle: LauncherLifecycleStore
	let accentColor: Color
	let canSwitchRegion: Bool
	let selectRegion: @MainActor @Sendable (GameRegion) -> Void

	var body: some View {
		OnboardingPage(
			title: L10n.string(OnboardingStrings.installationTitle),
			subtitle: L10n.string(OnboardingStrings.installationSubtitle),
			accentColor: accentColor
		) {
			OnboardingCanaryPanel(
				title: L10n.string(OnboardingStrings.canaryFeatures),
			) {
				OnboardingToggleRow(
					title: L10n.string(OnboardingStrings.canaryFeatures),
					detail: L10n.string(OnboardingStrings.canaryFeaturesDetail),
					isOn: $preferences.canaryFeaturesEnabled,
					accentColor: LauncherVisuals.danger
				)
				.disabled(lifecycle.activity != .idle)
			}

			SettingsPanel(
				title: L10n.string(OnboardingStrings.serverRegion),
				systemImage: "globe.asia.australia"
			) {
				AdaptiveSegmentedControl(
					selection: regionBinding,
					options: GameRegion.selectableCases(
						canaryEnabled: preferences.canaryFeaturesEnabled
					),
					accentColor: accentColor
				) { region in
					Text(region.localizedDisplayName)
				}
				.disabled(!canSwitchRegion)
				Text(L10n.string(regionDetail))
					.font(.callout)
					.foregroundStyle(.secondary)
			}

			SettingsPanel(
				title: L10n.string(OnboardingStrings.officialClient), systemImage: installationImage
			) {
				HStack {
					VStack(alignment: .leading, spacing: 4) {
						if isLoadingInstallationMetadata {
							SkeletonValue(width: 160, height: 17, pulses: true)
							SkeletonValue(width: 216, height: 15, pulses: true)
						} else {
							Text(L10n.string(installationTitle))
								.bold()
							Text(L10n.string(installationDetail))
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
					Text(
						"\(ByteCountFormatter.string(fromByteCount: progress.downloadedBytes, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: progress.totalBytes, countStyle: .file))"
					)
					.font(.caption.monospacedDigit())
					.foregroundStyle(.secondary)
				}

				if !installation.isInstalled && !installation.isDownloading {
					Text(L10n.string(OnboardingStrings.installDownloadDetail))
						.font(.callout)
						.foregroundStyle(.secondary)
				}
			}
		}
	}

	private var regionDetail: LocalizedStringResource {
		OnboardingStrings.regionDetail(installation.region)
	}

	private var installationImage: String {
		if installation.isDownloading { return "arrow.down.circle" }
		if installation.isInstalled { return "checkmark.circle" }
		return "externaldrive.badge.plus"
	}

	private var installationTitle: LocalizedStringResource {
		if installation.isDownloading { return OnboardingStrings.downloadingTitle }
		if installation.isInstalled { return OnboardingStrings.existingTitle }
		if installation.hasPartialDownload { return OnboardingStrings.partialTitle }
		return OnboardingStrings.readyToInstall(installation.region.localizedDisplayName)
	}

	private var installationDetail: LocalizedStringResource {
		if installation.isDownloading { return OnboardingStrings.downloadingDetail }
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

	private var regionBinding: Binding<GameRegion> {
		Binding(get: { installation.region }, set: { selectRegion($0) })
	}
}
