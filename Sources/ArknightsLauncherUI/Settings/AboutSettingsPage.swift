// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsCustomization
import SwiftUI

struct AboutSettingsPage: View {
	package let accentColor: Color
	package let launcherIconManager: LauncherIconManager
	let branding: LauncherBranding?
	let revealApplication: () -> Void
	@Binding var presentedDocument: BundledDocument?

	var body: some View {
		SettingsPage(
			title: "About",
			subtitle: "\("Arknights Client") \(appVersion)",
			accentColor: accentColor
		) {
			SettingsPanel(title: "Arknights Client", systemImage: "info.circle") {
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

			SettingsPanel(title: "Documents", systemImage: "doc.text") {
				ViewThatFits(in: .horizontal) {
					HStack(spacing: LauncherVisuals.Spacing.tight) {
						documentLink(
							.changelog, title: "Changelog",
							systemImage: "clock.arrow.circlepath"
						)
						.frame(maxWidth: .infinity)
						documentLink(
							.projectLicense, title: "MPL-2.0 License",
							systemImage: "checkmark.seal"
						)
						.frame(maxWidth: .infinity)
						documentLink(
							.thirdPartyNotices, title: "Third-Party Notices",
							systemImage: "doc.on.doc"
						)
						.frame(maxWidth: .infinity)
					}
					VStack(spacing: 0) {
						documentLink(
							.changelog, title: "Changelog",
							systemImage: "clock.arrow.circlepath")
						SettingsHairline()
						documentLink(
							.projectLicense, title: "MPL-2.0 License",
							systemImage: "checkmark.seal")
						SettingsHairline()
						documentLink(
							.thirdPartyNotices, title: "Third-Party Notices",
							systemImage: "doc.on.doc")
					}
				}
				HStack(spacing: 18) {
					AccentLink(
						title: "View online",
						destination: SupportLinks.thirdPartyNotices,
						accentColor: accentColor
					)
					AccentLink(
						title: "Privacy Notice",
						destination: SupportLinks.privacyNotice,
						accentColor: accentColor
					)
				}
				.font(.caption)
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
					Text(
						"This launcher is an independent community project and is not affiliated with Hypergryph, its affiliates, or any third-party publisher."
					)
					.font(.caption)
					.foregroundStyle(.secondary)
					HStack(spacing: 4) {
						Text("Built with AI assistance.")
							.foregroundStyle(.secondary)
						AccentLink(
							title: "Learn more",
							destination: URL(
								string:
									"https://github.com/LuMiSxh/Arknights-MacOS-Client/blob/main/docs/ai-assistance.md"
							)!,
							accentColor: accentColor
						)
					}
					.font(.caption)
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
				Text("Unofficial macOS launcher")
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
				title: "Show in Finder", systemImage: "folder",
				tone: .neutral, showsTitle: false,
				action: revealApplication
			)
			.help("Reveal the launcher application in Finder")
			CapsuleActionButton(
				title: "GitHub", tone: .neutral
			) {
				NSWorkspace.shared.open(
					URL(string: "https://github.com/LuMiSxh/Arknights-MacOS-Client")!
				)
			}
			.help("Open project repository")
			CapsuleActionButton(
				title: "Donate",
				systemImage: "heart.fill",
				tone: .neutral
			) {
				NSWorkspace.shared.open(SupportLinks.donate)
			}
			.help("Support the project on Ko-fi")
		}
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
				title: "User Agreement",
				destination: agreement,
				accentColor: accentColor
			)
		}
		if let privacy = branding?.privacyPolicy {
			AccentLink(
				title: "Privacy Policy",
				destination: privacy,
				accentColor: accentColor
			)
		}
	}
}
