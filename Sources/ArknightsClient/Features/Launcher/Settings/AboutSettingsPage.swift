// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

struct AboutSettingsPage: View {
	var model: LauncherViewModel
	@Binding var presentedDocument: BundledDocument?

	var body: some View {
		SettingsPage(
			title: L10n.string(SettingsStrings.aboutTitle),
			subtitle: "\(L10n.string(SettingsStrings.application)) \(appVersion)",
			accentColor: model.accentColor
		) {
			HStack(alignment: .center, spacing: 18) {
				Image(nsImage: model.launcherIconManager.currentIcon)
					.resizable()
					.frame(width: 76, height: 76)
				VStack(alignment: .leading, spacing: 5) {
					Text(SettingsStrings.application)
						.font(.title2.bold())
					Text(SettingsStrings.unofficialLauncher)
						.foregroundStyle(.secondary)
					AccentLink(
						title: "LuMiSxh", destination: URL(string: "https://github.com/LuMiSxh")!,
						accentColor: model.accentColor
					)
					.font(.callout.weight(.medium))
				}
				Spacer()
				CapsuleActionButton(
					title: L10n.string(SettingsStrings.openFinder), systemImage: "folder",
					tone: .accent(model.accentColor), showsTitle: false,
					action: model.revealApplication
				)
				.help(L10n.string(SettingsStrings.openFinderHelp))
				CapsuleActionButton(
					title: L10n.string(SettingsStrings.github), tone: .accent(model.accentColor)
				) {
					NSWorkspace.shared.open(
						URL(
							string: "https://github.com/LuMiSxh/Arknights-MacOS-Client"
						)!
					)
				}
				.help(L10n.string(SettingsStrings.githubHelp))
			}
			.padding(20)
			.adaptiveGlassEffect(in: .rect(cornerRadius: 20))

			SettingsPanel(title: L10n.string(SettingsStrings.documents), systemImage: "doc.text") {
				DocumentLinkRow(
					title: L10n.string(SettingsStrings.changelog),
					systemImage: "clock.arrow.circlepath",
					accentColor: model.accentColor
				) {
					presentedDocument = .changelog
				}
				SettingsHairline()
				DocumentLinkRow(
					title: L10n.string(SettingsStrings.license), systemImage: "checkmark.seal",
					accentColor: model.accentColor
				) {
					presentedDocument = .projectLicense
				}
				SettingsHairline()
				DocumentLinkRow(
					title: L10n.string(SettingsStrings.thirdPartyNotices),
					systemImage: "shippingbox",
					accentColor: model.accentColor
				) {
					presentedDocument = .thirdPartyNotices
				}
			}

			SettingsPanel(
				title: L10n.string(SettingsStrings.support), systemImage: "questionmark.circle"
			) {
				SettingsActionRow(
					title: L10n.string(SettingsStrings.launcherIssues),
					detail: L10n.string(SettingsStrings.launcherIssuesDetail)
				) {
					CapsuleActionButton(
						L10n.string(SettingsStrings.report), systemImage: "ladybug",
						tone: .accent(model.accentColor), presentation: .compact,
						action: reportLauncherProblem
					)
				}

				SettingsHairline()

				SettingsActionRow(
					title: L10n.string(SettingsStrings.gameAccountIssues),
					detail: L10n.string(SettingsStrings.gameAccountIssuesDetail)
				) {
					CapsuleActionButton(
						L10n.string(SettingsStrings.contactYostar),
						systemImage: "arrow.up.right.square",
						tone: .accent(model.accentColor), presentation: .compact,
						action: contactYostar
					)
				}
			}

			SettingsPanel(title: "Arknights", systemImage: "link") {
				HStack(spacing: 18) {
					if let agreement = model.branding?.userAgreement {
						AccentLink(
							title: L10n.string(SettingsStrings.userAgreement),
							destination: agreement,
							accentColor: model.accentColor
						)
					}
					if let privacy = model.branding?.privacyPolicy {
						AccentLink(
							title: L10n.string(SettingsStrings.privacyPolicy), destination: privacy,
							accentColor: model.accentColor
						)
					}
					Spacer()
					Text(SettingsStrings.notAffiliated)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
		}
	}

	private var appVersion: String { IssueReportURL.appVersion }

	private func reportLauncherProblem() {
		NSWorkspace.shared.open(IssueReportURL.build())
	}

	private func contactYostar() {
		NSWorkspace.shared.open(SupportLinks.yostarContact)
	}
}
