// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

struct AboutSettingsPage: View {
	let region: GameRegion
	let accentColor: Color
	let launcherIconManager: LauncherIconManager
	let branding: LauncherBranding?
	let revealApplication: () -> Void
	@Binding var presentedDocument: BundledDocument?

	var body: some View {
		SettingsPage(
			title: L10n.string(SettingsStrings.aboutTitle),
			subtitle: "\(L10n.string(SettingsStrings.application)) \(appVersion)",
			accentColor: accentColor
		) {
			HStack(alignment: .center, spacing: 18) {
				Image(nsImage: launcherIconManager.currentIcon)
					.resizable()
					.frame(width: 76, height: 76)
					.accessibilityHidden(true)
				VStack(alignment: .leading, spacing: 5) {
					Text(L10n.string(SettingsStrings.application))
						.font(.title2.bold())
					Text(L10n.string(SettingsStrings.unofficialLauncher))
						.foregroundStyle(.secondary)
					AccentLink(
						title: "LuMiSxh", destination: URL(string: "https://github.com/LuMiSxh")!,
						accentColor: accentColor
					)
					.font(.callout.weight(.medium))
				}
				Spacer()
				CapsuleActionButton(
					title: L10n.string(SettingsStrings.openFinder), systemImage: "folder",
					tone: .accent(accentColor), showsTitle: false,
					action: revealApplication
				)
				.help(L10n.string(SettingsStrings.openFinderHelp))
				CapsuleActionButton(
					title: L10n.string(SettingsStrings.github), tone: .accent(accentColor)
				) {
					NSWorkspace.shared.open(
						URL(
							string: "https://github.com/LuMiSxh/Arknights-MacOS-Client"
						)!
					)
				}
				.help(L10n.string(SettingsStrings.githubHelp))
				CapsuleActionButton(
					title: L10n.string(SettingsStrings.donate),
					systemImage: "heart.fill",
					tone: .accent(accentColor)
				) {
					NSWorkspace.shared.open(SupportLinks.donate)
				}
				.help(L10n.string(SettingsStrings.donateHelp))
			}
			.padding(20)
			.adaptiveGlassEffect(in: .rect(cornerRadius: 20))

			SettingsPanel(title: L10n.string(SettingsStrings.documents), systemImage: "doc.text") {
				DocumentLinkRow(
					title: L10n.string(SettingsStrings.changelog),
					systemImage: "clock.arrow.circlepath",
					accentColor: accentColor
				) {
					presentedDocument = .changelog
				}
				SettingsHairline()
				DocumentLinkRow(
					title: L10n.string(SettingsStrings.license), systemImage: "checkmark.seal",
					accentColor: accentColor
				) {
					presentedDocument = .projectLicense
				}
				SettingsHairline()
				DocumentLinkRow(
					title: L10n.string(SettingsStrings.thirdPartyNotices),
					systemImage: "shippingbox",
					accentColor: accentColor
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
						title: L10n.string(SettingsStrings.report), systemImage: "ladybug",
						tone: .accent(accentColor), presentation: .compact,
						action: reportLauncherProblem
					)
				}

				SettingsHairline()

				SettingsActionRow(
					title: L10n.string(SettingsStrings.gameAccountIssues),
					detail: L10n.string(SettingsStrings.gameAccountIssuesDetail(region: region))
				) {
					CapsuleActionButton(
						title: L10n.string(SettingsStrings.contactPublisherTitle(region: region)),
						systemImage: "arrow.up.right.square",
						tone: .accent(accentColor), presentation: .compact,
						action: contactPublisher
					)
				}
			}

			SettingsPanel(title: "Arknights", systemImage: "link") {
				VStack(alignment: .leading, spacing: 8) {
					HStack(spacing: 18) {
						if let agreement = branding?.userAgreement {
							AccentLink(
								title: L10n.string(SettingsStrings.userAgreement),
								destination: agreement,
								accentColor: accentColor
							)
						}
						if let privacy = branding?.privacyPolicy {
							AccentLink(
								title: L10n.string(SettingsStrings.privacyPolicy),
								destination: privacy,
								accentColor: accentColor
							)
						}
					}
					Text(L10n.string(SettingsStrings.notAffiliated))
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

	private func contactPublisher() {
		NSWorkspace.shared.open(SupportLinks.contact(for: region))
	}
}
