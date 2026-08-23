// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

struct OnboardingFinishView: View {
	let model: LauncherViewModel

	var body: some View {
		OnboardingPage(
			title: L10n.string(OnboardingStrings.finishTitle),
			subtitle: L10n.string(OnboardingStrings.finishSubtitle),
			accentColor: model.accentColor
		) {
			SettingsPanel(title: L10n.string(gameStatusTitle), systemImage: gameStatusImage) {
				Text(gameStatusDetail)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)

				if model.isDownloading, let progress = model.progress {
					ProgressView(value: progress.fraction)
						.tint(model.accentColor)
				}

				if !model.isInstalled && !model.isDownloading && model.canInstall {
					CapsuleActionButton(
						L10n.string(OnboardingStrings.resumeDownload),
						systemImage: "arrow.clockwise",
						tone: .accent(model.accentColor),
						action: model.installOrUpdate
					)
				}
			}

			SettingsPanel(
				title: L10n.string(OnboardingStrings.communityTitle), systemImage: "person.3"
			) {
				Text(OnboardingStrings.communityDetail)
					.fixedSize(horizontal: false, vertical: true)
				Text(OnboardingStrings.issueDetail)
					.font(.callout)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
				CapsuleActionButton(
					title: L10n.string(OnboardingStrings.reportProblem), systemImage: "ladybug",
					tone: .accent(model.accentColor), action: reportProblem
				)

				SettingsHairline()

				Text(OnboardingStrings.communitySupport)
					.font(.callout)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
				CapsuleActionButton(
					L10n.string(OnboardingStrings.contactSupport),
					systemImage: "arrow.up.right.square",
					tone: .accent(model.accentColor),
					action: contactYostar
				)
			}
		}
	}

	private var gameStatusTitle: LocalizedStringResource {
		if model.isGameActive { return OnboardingStrings.finishStatusRunning }
		if model.isDownloading { return OnboardingStrings.finishStatusDownloading }
		if model.isInstalled { return OnboardingStrings.finishStatusInstalled }
		return OnboardingStrings.finishStatusPaused
	}

	private var gameStatusImage: String {
		if model.isGameActive { return "gamecontroller.fill" }
		if model.isDownloading { return "arrow.down.circle" }
		if model.isInstalled { return "checkmark.circle" }
		return "pause.circle"
	}

	private var gameStatusDetail: LocalizedStringResource {
		if model.isGameActive { return OnboardingStrings.finishGameActiveDetail }
		if model.isDownloading { return OnboardingStrings.finishDownloadingDetail }
		if model.isInstalled { return OnboardingStrings.finishInstalledDetail }
		return OnboardingStrings.finishPausedDetail
	}

	private func reportProblem() {
		NSWorkspace.shared.open(IssueReportURL.build())
	}

	private func contactYostar() {
		NSWorkspace.shared.open(SupportLinks.yostarContact)
	}
}
