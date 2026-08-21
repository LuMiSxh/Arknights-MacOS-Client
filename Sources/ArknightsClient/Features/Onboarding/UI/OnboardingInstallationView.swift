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
			title: "Choose where you play",
			subtitle:
				"Regions use separate game files and accounts. Pick the server you already use; you can install another region later from Settings.",
			accentColor: model.accentColor
		) {
			SettingsPanel(title: "Server region", systemImage: "globe.asia.australia") {
				AdaptiveSegmentedControl(
					selection: $selectedRegion,
					options: GameRegion.allCases,
					accentColor: model.accentColor
				) { region in
					Text(region.displayName)
				}
				.disabled(!model.canSwitchRegion)
				.onChange(of: selectedRegion) { _, newRegion in
					model.selectRegion(newRegion)
				}
				Text(regionDetail)
					.font(.callout)
					.foregroundStyle(.secondary)
			}

			SettingsPanel(title: "Official PC client", systemImage: installationImage) {
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
					Text(
						"Selecting Install & Continue starts a resumable download. Closing the launcher pauses it safely."
					)
					.font(.callout)
					.foregroundStyle(.secondary)
				}
			}
		}
	}

	private var regionDetail: String {
		switch selectedRegion {
		case .global: "For the English Global client and Global Yostar accounts."
		case .japan: "For the Japanese client and Japan-region Yostar accounts."
		case .korea: "For the Korean client and Korea-region Yostar accounts."
		}
	}

	private var installationImage: String {
		if model.isDownloading { return "arrow.down.circle" }
		if model.isInstalled { return "checkmark.circle" }
		return "externaldrive.badge.plus"
	}

	private var installationTitle: String {
		if model.isDownloading { return "Downloading in the background" }
		if model.isInstalled { return "Existing installation found" }
		if model.hasPartialDownload { return "Paused download found" }
		return "Ready to install \(selectedRegion.displayName)"
	}

	private var installationDetail: String {
		if model.isDownloading { return "You can continue setup while the game files download." }
		if model.isInstalled {
			return
				"Arknights \(model.installedVersion ?? model.versionText) is ready in \(model.installDirectory.lastPathComponent)."
		}
		if model.hasPartialDownload {
			return "The installer will continue from verified partial files."
		}
		return "Download size after extraction: \(model.installSizeText)."
	}
}
