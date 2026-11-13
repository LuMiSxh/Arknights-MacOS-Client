// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

/// The Location panel of the install step. It reads `installation.progress` itself, so the
/// ~10 Hz download ticks redraw this panel and not the whole onboarding page. Its Change… menu
/// matches Settings → Installation.
struct OnboardingGameFilesPanel: View {
	let installation: InstallationController
	let lifecycle: LauncherLifecycleStore
	let chooseInstallDirectory: () -> Void
	let locateExistingInstallation: () -> Void
	@Environment(\.launcherTheme) private var theme

	var body: some View {
		SettingsPanel(title: "Location") {
			VStack(alignment: .leading, spacing: LauncherTokens.Spacing.content) {
				SettingsActionRow(
					title: "Game files",
					detail: (installation.installDirectory.path(percentEncoded: false) as NSString)
						.abbreviatingWithTildeInPath
				) {
					GlassActionMenu(
						title: "Change…",
						systemImage: "arrow.triangle.swap",
						isDisabled: !installation.canModifyGameFiles
					) {
						Button("Choose New Location…", action: chooseInstallDirectory)
						Button(
							"Locate Existing Installation…",
							action: locateExistingInstallation
						)
					}
				}

				HStack {
					VStack(alignment: .leading, spacing: LauncherTokens.Spacing.compact) {
						if isLoadingInstallationMetadata {
							SkeletonValue(width: 160, height: 16, pulses: true)
							SkeletonValue(width: 216, height: 16, pulses: true)
						} else {
							Text(installationTitle)
								.fontWeight(.medium)
							Text(installationDetail)
								.font(.callout)
								.foregroundStyle(theme.textSecondary)
						}
					}
					Spacer()
					if installation.lifecycle.state.refresh.isChecking {
						ProgressView()
					} else if installation.isInstalled && !installation.isDownloading {
						Image(systemName: "checkmark.circle.fill")
							.foregroundStyle(theme.accentInk)
							.accessibilityHidden(true)
					}
				}

				if installation.isDownloading, let progress = installation.progress {
					ProgressView(value: progress.fraction)
						.tint(theme.accentFill)
						.accessibilityLabel(Text(installationTitle))
					Text(progress.transferSummary)
						.font(.caption.monospacedDigit())
						.foregroundStyle(theme.textSecondary)
				}

				if let failure = gameFailure {
					InlineFailureView(message: failure.message, code: failure.code)
				}

				if !installation.isInstalled && !installation.isDownloading {
					Text(
						"Download and Continue starts the download. Closing the launcher pauses it safely."
					)
					.font(.callout)
					.foregroundStyle(theme.textSecondary)
				}
			}
		}
	}

	// The Home failure sheet waits while setup is visible, so a download failure shows here.
	private var gameFailure: LauncherFailurePresentation? {
		lifecycle.state.presentation.failure.flatMap { $0.isGameDownloadFailure ? $0 : nil }
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
}
