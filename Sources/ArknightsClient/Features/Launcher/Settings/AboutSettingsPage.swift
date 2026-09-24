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
			SettingsPanel(title: SettingsStrings.application, systemImage: "info.circle") {
				ViewThatFits(in: .horizontal) {
					HStack(alignment: .center, spacing: LauncherVisuals.Spacing.content) {
						identitySummary
						Spacer(minLength: 0)
						identityActions
					}
					VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.content) {
						identitySummary
						HStack {
							Spacer(minLength: 0)
							identityActions
						}
					}
				}
			}

			SettingsPanel(title: SettingsStrings.documents, systemImage: "doc.text") {
				ViewThatFits(in: .horizontal) {
					HStack(spacing: LauncherVisuals.Spacing.tight) {
						documentLink(
							.changelog, title: SettingsStrings.changelog,
							systemImage: "clock.arrow.circlepath"
						)
						.frame(maxWidth: .infinity)
						documentLink(
							.projectLicense, title: SettingsStrings.license,
							systemImage: "checkmark.seal"
						)
						.frame(maxWidth: .infinity)
						documentLink(
							.thirdPartyNotices, title: SettingsStrings.thirdPartyNotices,
							systemImage: "doc.on.doc"
						)
						.frame(maxWidth: .infinity)
					}
					VStack(spacing: 0) {
						documentLink(
							.changelog, title: SettingsStrings.changelog,
							systemImage: "clock.arrow.circlepath")
						SettingsHairline()
						documentLink(
							.projectLicense, title: SettingsStrings.license,
							systemImage: "checkmark.seal")
						SettingsHairline()
						documentLink(
							.thirdPartyNotices, title: SettingsStrings.thirdPartyNotices,
							systemImage: "doc.on.doc")
					}
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
						tone: .neutral, presentation: .compact,
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
						tone: .neutral, presentation: .compact,
						action: contactPublisher
					)
				}
			}

			SettingsPanel(title: "Arknights", systemImage: "link") {
				VStack(alignment: .leading, spacing: 8) {
					ViewThatFits(in: .horizontal) {
						HStack(spacing: 18) {
							publisherLinks
						}
						VStack(alignment: .leading, spacing: 8) {
							publisherLinks
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

	@ViewBuilder
	private var identitySummary: some View {
		HStack(alignment: .center, spacing: LauncherVisuals.Spacing.content) {
			Image(nsImage: launcherIconManager.currentIcon)
				.resizable()
				.frame(width: 76, height: 76)
				.accessibilityHidden(true)
			VStack(alignment: .leading, spacing: LauncherVisuals.Spacing.tight) {
				Text(SettingsStrings.unofficialLauncher)
					.foregroundStyle(.secondary)
				AccentLink(
					title: "LuMiSxh", destination: URL(string: "https://github.com/LuMiSxh")!,
					accentColor: accentColor
				)
				.font(.callout.weight(.medium))
			}
		}
	}

	@ViewBuilder
	private var identityActions: some View {
		HStack(spacing: LauncherVisuals.Spacing.tight) {
			CapsuleActionButton(
				title: SettingsStrings.openFinder, systemImage: "folder",
				tone: .neutral, showsTitle: false,
				action: revealApplication
			)
			.help(SettingsStrings.openFinderHelp)
			CapsuleActionButton(
				title: SettingsStrings.github, tone: .neutral
			) {
				NSWorkspace.shared.open(
					URL(string: "https://github.com/LuMiSxh/Arknights-MacOS-Client")!
				)
			}
			.help(SettingsStrings.githubHelp)
			CapsuleActionButton(
				title: SettingsStrings.donate,
				systemImage: "heart.fill",
				tone: .neutral
			) {
				NSWorkspace.shared.open(SupportLinks.donate)
			}
			.help(SettingsStrings.donateHelp)
		}
	}

	private func reportLauncherProblem() {
		NSWorkspace.shared.open(IssueReportURL.build())
	}

	private func contactPublisher() {
		NSWorkspace.shared.open(SupportLinks.contact(for: region))
	}

	@ViewBuilder
	private func documentLink(
		_ document: BundledDocument,
		title: String,
		systemImage: String
	) -> some View {
		DocumentLinkRow(
			title: title,
			systemImage: systemImage,
			accentColor: accentColor
		) {
			presentedDocument = document
		}
	}

	@ViewBuilder
	private var publisherLinks: some View {
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
}
