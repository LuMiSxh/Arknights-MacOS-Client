// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

struct OnboardingFinishView: View {
	let installation: InstallationController
	let lifecycle: LauncherLifecycleStore
	let accentColor: Color
	let install: () -> Void

	var body: some View {
		OnboardingPage(
			title: L10n.string(OnboardingStrings.finishTitle),
			subtitle: L10n.string(OnboardingStrings.finishSubtitle),
			accentColor: accentColor
		) {
			SettingsPanel(title: L10n.string(gameStatusTitle), systemImage: gameStatusImage) {
				Text(L10n.string(gameStatusDetail))
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)

				if installation.isDownloading, let progress = installation.progress {
					ProgressView(value: progress.fraction)
						.tint(accentColor)
				}

				if !installation.isInstalled && !installation.isDownloading
					&& installation.canInstall
				{
					CapsuleActionButton(
						title: L10n.string(OnboardingStrings.resumeDownload),
						systemImage: "arrow.clockwise",
						tone: .accent(accentColor),
						action: install
					)
				}
			}

			SettingsPanel(
				title: L10n.string(OnboardingStrings.communityTitle), systemImage: "person.3"
			) {
				Text(L10n.string(OnboardingStrings.communityDetail))
					.fixedSize(horizontal: false, vertical: true)
				Text(L10n.string(OnboardingStrings.issueDetail))
					.font(.callout)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
				CapsuleActionButton(
					title: L10n.string(OnboardingStrings.reportProblem), systemImage: "ladybug",
					tone: .accent(accentColor), action: reportProblem
				)

				SettingsHairline()

				Text(L10n.string(OnboardingStrings.communitySupport(region: installation.region)))
					.font(.callout)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
				CapsuleActionButton(
					title: L10n.string(
						OnboardingStrings.contactSupport(region: installation.region)
					),
					systemImage: "arrow.up.right.square",
					tone: .accent(accentColor),
					action: contactPublisher
				)
			}
		}
	}

	private var gameStatusTitle: LocalizedStringResource {
		if lifecycle.activity.isGameActive { return OnboardingStrings.finishStatusRunning }
		if installation.isDownloading { return OnboardingStrings.finishStatusDownloading }
		if installation.isInstalled { return OnboardingStrings.finishStatusInstalled }
		return OnboardingStrings.finishStatusPaused
	}

	private var gameStatusImage: String {
		if lifecycle.activity.isGameActive { return "gamecontroller.fill" }
		if installation.isDownloading { return "arrow.down.circle" }
		if installation.isInstalled { return "checkmark.circle" }
		return "pause.circle"
	}

	private var gameStatusDetail: LocalizedStringResource {
		if lifecycle.activity.isGameActive { return OnboardingStrings.finishGameActiveDetail }
		if installation.isDownloading { return OnboardingStrings.finishDownloadingDetail }
		if installation.isInstalled { return OnboardingStrings.finishInstalledDetail }
		return OnboardingStrings.finishPausedDetail
	}

	private func reportProblem() {
		NSWorkspace.shared.open(IssueReportURL.build())
	}

	private func contactPublisher() {
		NSWorkspace.shared.open(SupportLinks.contact(for: installation.region))
	}
}
