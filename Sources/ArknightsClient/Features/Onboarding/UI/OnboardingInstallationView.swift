// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingInstallationView: View {
	@Bindable var model: LauncherViewModel
	@State private var selectedRegion: GameRegion

	init(model: LauncherViewModel) {
		self.model = model
		_selectedRegion = State(initialValue: model.region)
	}

	var body: some View {
		OnboardingPage(
			title: L10n.string(OnboardingStrings.installationTitle),
			subtitle: L10n.string(OnboardingStrings.installationSubtitle),
			accentColor: model.accentColor
		) {
			SettingsPanel(
				title: L10n.string(OnboardingStrings.serverRegion),
				systemImage: "globe.asia.australia"
			) {
				AdaptiveSegmentedControl(
					selection: $selectedRegion,
					options: GameRegion.allCases,
					accentColor: model.accentColor
				) { region in
					Text(region.localizedDisplayName)
				}
				.disabled(!model.canSwitchRegion)
				.onChange(of: selectedRegion) { _, newRegion in
					model.selectRegion(newRegion)
				}
				Text(regionDetail)
					.font(.callout)
					.foregroundStyle(.secondary)
			}

			SettingsPanel(
				title: L10n.string(OnboardingStrings.officialClient), systemImage: installationImage
			) {
				HStack {
					VStack(alignment: .leading, spacing: 4) {
						Text(installationTitle)
							.bold()
						Text(installationDetail)
							.font(.callout)
							.foregroundStyle(.secondary)
					}
					Spacer()
					if model.phase == .checking {
						ProgressView()
					} else if model.isInstalled && !model.isDownloading {
						Image(systemName: "checkmark.circle.fill")
							.foregroundStyle(model.accentColor)
					}
				}

				if model.isDownloading, let progress = model.progress {
					ProgressView(value: progress.fraction)
						.tint(model.accentColor)
					Text(
						"\(ByteCountFormatter.string(fromByteCount: progress.downloadedBytes, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: progress.totalBytes, countStyle: .file))"
					)
					.font(.caption.monospacedDigit())
					.foregroundStyle(.secondary)
				}

				if !model.isInstalled && !model.isDownloading {
					Text(OnboardingStrings.installDownloadDetail)
						.font(.callout)
						.foregroundStyle(.secondary)
				}
			}
		}
	}

	private var regionDetail: LocalizedStringResource {
		OnboardingStrings.regionDetail(selectedRegion)
	}

	private var installationImage: String {
		if model.isDownloading { return "arrow.down.circle" }
		if model.isInstalled { return "checkmark.circle" }
		return "externaldrive.badge.plus"
	}

	private var installationTitle: LocalizedStringResource {
		if model.isDownloading { return OnboardingStrings.downloadingTitle }
		if model.isInstalled { return OnboardingStrings.existingTitle }
		if model.hasPartialDownload { return OnboardingStrings.partialTitle }
		return OnboardingStrings.readyToInstall(selectedRegion.localizedDisplayName)
	}

	private var installationDetail: LocalizedStringResource {
		if model.isDownloading { return OnboardingStrings.downloadingDetail }
		if model.isInstalled {
			return OnboardingStrings.installationExisting(
				version: model.installedVersion ?? model.versionText,
				directory: model.installDirectory.lastPathComponent
			)
		}
		if model.hasPartialDownload { return OnboardingStrings.partialDetail }
		return OnboardingStrings.installationSize(model.installSizeText)
	}
}
