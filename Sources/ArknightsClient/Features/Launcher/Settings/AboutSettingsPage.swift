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
			title: SettingsStrings.aboutTitle,
			subtitle: "\(SettingsStrings.application) \(appVersion)",
			accentColor: accentColor
		) {
			HStack(alignment: .center, spacing: 18) {
				Image(nsImage: launcherIconManager.currentIcon)
					.resizable()
					.frame(width: 76, height: 76)
					.accessibilityHidden(true)
				VStack(alignment: .leading, spacing: 5) {
					Text(SettingsStrings.application)
						.font(.title2.bold())
					Text(SettingsStrings.unofficialLauncher)
						.foregroundStyle(.secondary)
					AccentLink(
						title: "LuMiSxh", destination: URL(string: "https://github.com/LuMiSxh")!,
						accentColor: accentColor
					)
					.font(.callout.weight(.medium))
				}
				Spacer()
				CapsuleActionButton(
					title: SettingsStrings.openFinder, systemImage: "folder",
					tone: .accent(accentColor), showsTitle: false,
					action: revealApplication
				)
				.help(SettingsStrings.openFinderHelp)
				CapsuleActionButton(
					title: SettingsStrings.github, tone: .accent(accentColor)
				) {
					NSWorkspace.shared.open(
						URL(
							string: "https://github.com/LuMiSxh/Arknights-MacOS-Client"
						)!
					)
				}
				.help(SettingsStrings.githubHelp)
				CapsuleActionButton(
					title: SettingsStrings.donate,
					systemImage: "heart.fill",
					tone: .accent(accentColor)
				) {
					NSWorkspace.shared.open(SupportLinks.donate)
				}
				.help(SettingsStrings.donateHelp)
			}
			.padding(20)
			.adaptiveGlassEffect(in: .rect(cornerRadius: 20))

			SettingsPanel(title: SettingsStrings.documents, systemImage: "doc.text") {
				DocumentLinkRow(
					title: SettingsStrings.changelog,
					systemImage: "clock.arrow.circlepath",
					accentColor: accentColor
				) {
					presentedDocument = .changelog
				}
				SettingsHairline()
				DocumentLinkRow(
					title: SettingsStrings.license, systemImage: "checkmark.seal",
					accentColor: accentColor
				) {
					presentedDocument = .projectLicense
				}
				SettingsHairline()
				DocumentLinkRow(
					title: SettingsStrings.thirdPartyNotices,
					systemImage: "shippingbox",
					accentColor: accentColor
				) {
					presentedDocument = .thirdPartyNotices
				}
			}

			SettingsPanel(
				title: SettingsStrings.support, systemImage: "questionmark.circle"
			) {
				SettingsActionRow(
					title: SettingsStrings.launcherIssues,
					detail: SettingsStrings.launcherIssuesDetail
				) {
					CapsuleActionButton(
						title: SettingsStrings.report, systemImage: "ladybug",
						tone: .accent(accentColor), presentation: .compact,
						action: reportLauncherProblem
					)
				}

				SettingsHairline()

				SettingsActionRow(
					title: SettingsStrings.gameAccountIssues,
					detail: SettingsStrings.gameAccountIssuesDetail(region: region)
				) {
					CapsuleActionButton(
						title: SettingsStrings.contactPublisherTitle(region: region),
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
								title: SettingsStrings.userAgreement,
								destination: agreement,
								accentColor: accentColor
							)
						}
						if let privacy = branding?.privacyPolicy {
							AccentLink(
								title: SettingsStrings.privacyPolicy,
								destination: privacy,
								accentColor: accentColor
							)
						}
					}
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

	private func contactPublisher() {
		NSWorkspace.shared.open(SupportLinks.contact(for: region))
	}
}
