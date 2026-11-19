// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsCustomization
import Foundation
import SwiftUI

struct AboutSettingsPage: View {
	@Environment(\.launcherTheme) private var theme
	let launcherIconManager: LauncherIconManager
	let branding: LauncherBranding?
	let revealApplication: () -> Void
	@Binding var presentedDocument: BundledDocument?

	var body: some View {
		SettingsPage(
			title: "About",
			subtitle: "Arknights Client, version \(appVersion)"
		) {
			SettingsPanel(title: "Arknights Client") {
				ViewThatFits(in: .horizontal) {
					HStack(alignment: .center, spacing: LauncherTokens.Spacing.content) {
						identitySummary
						Spacer(minLength: 0)
						identityActions
					}
					VStack(alignment: .leading, spacing: LauncherTokens.Spacing.content) {
						identitySummary
						HStack {
							Spacer(minLength: 0)
							identityActions
						}
					}
				}
			}

			SettingsPanel(title: "Documents") {
				ViewThatFits(in: .horizontal) {
					HStack(spacing: LauncherTokens.Spacing.control) {
						documentLinks(isInline: true)
					}
					VStack(spacing: 0) {
						documentLinks(isInline: false)
					}
				}
				HStack(spacing: LauncherTokens.Spacing.panel) {
					QuietLink(title: "View online", destination: SupportLinks.thirdPartyNotices)
					QuietLink(title: "Privacy Notice", destination: SupportLinks.privacyNotice)
				}
				.font(.caption)
			}

			SettingsPanel(title: "Arknights") {
				VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
					ViewThatFits(in: .horizontal) {
						HStack(spacing: LauncherTokens.Spacing.panel) {
							publisherLinks
						}
						VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
							publisherLinks
						}
					}
					Text(
						"This launcher is an independent community project and is not affiliated with Hypergryph, its affiliates, or any third-party publisher."
					)
					.font(.caption)
					.foregroundStyle(theme.textSecondary)
					HStack(spacing: LauncherTokens.Spacing.compact) {
						Text("Built with AI assistance.")
							.foregroundStyle(theme.textSecondary)
						QuietLink(title: "Learn more", destination: SupportLinks.aiAssistance)
					}
					.font(.caption)
				}
			}
		}
	}

	private var appVersion: String { IssueReportURL.appVersion }

	@ViewBuilder
	private var identitySummary: some View {
		HStack(alignment: .center, spacing: LauncherTokens.Spacing.content) {
			Image(nsImage: launcherIconManager.currentIcon)
				.resizable()
				.frame(
					width: LauncherTokens.Layout.aboutIconSize,
					height: LauncherTokens.Layout.aboutIconSize
				)
				.accessibilityHidden(true)
			VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
				Text("Unofficial macOS launcher")
					.foregroundStyle(theme.textSecondary)
				QuietLink(
					title: "LuMiSxh",
					destination: SupportLinks.maintainerProfile
				)
				.font(.callout.weight(.medium))
			}
		}
	}

	@ViewBuilder
	private var identityActions: some View {
		HStack(spacing: LauncherTokens.Spacing.control) {
			ExternalLinkButton(
				title: "Show in Finder", presentation: .standard,
				action: revealApplication
			)
			ExternalLinkButton(title: "View on GitHub", presentation: .standard) {
				NSWorkspace.shared.open(SupportLinks.sourceRepository)
			}
			.help("Open project repository")
			ExternalLinkButton(title: "Donate", presentation: .standard) {
				NSWorkspace.shared.open(SupportLinks.donate)
			}
			.help("Support the project on Ko-fi")
		}
	}

	@ViewBuilder
	private func documentLink(
		_ document: BundledDocument,
		systemImage: String
	) -> some View {
		DocumentLinkRow(
			title: document.title,
			systemImage: systemImage
		) {
			presentedDocument = document
		}
	}

	/// Lists the documents once for both layouts. The inline row fills its width; the
	/// stacked list separates rows with hairlines.
	@ViewBuilder
	private func documentLinks(isInline: Bool) -> some View {
		documentLink(
			.changelog,
			systemImage: "clock.arrow.circlepath"
		)
		.frame(maxWidth: isInline ? .infinity : nil)
		if !isInline { SettingsHairline() }
		documentLink(
			.projectLicense,
			systemImage: "checkmark.seal"
		)
		.frame(maxWidth: isInline ? .infinity : nil)
		if !isInline { SettingsHairline() }
		documentLink(
			.thirdPartyNotices,
			systemImage: "doc.on.doc"
		)
		.frame(maxWidth: isInline ? .infinity : nil)
	}

	@ViewBuilder
	private var publisherLinks: some View {
		if let agreement = branding?.userAgreement {
			QuietLink(title: "User Agreement", destination: agreement)
		}
		if let privacy = branding?.privacyPolicy {
			QuietLink(title: "Privacy Policy", destination: privacy)
		}
	}
}
