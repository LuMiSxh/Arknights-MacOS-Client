// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsCustomization
import ArknightsGameRuntime
import SwiftUI

struct AboutSettingsPage: View {
	@Environment(\.launcherTheme) private var theme
	let launcherIconManager: LauncherIconManager
	let branding: LauncherBranding?
	let runtime: InstalledRuntimeDetails?
	let revealApplication: () -> Void
	@Binding var presentedDocument: BundledDocument?
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var isShowingTechnicalDetails = false

	var body: some View {
		SettingsPage(
			title: "About",
			subtitle: "Arknights Client, Version \(appVersion)"
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

			SettingsPanel(title: "Runtime") {
				runtimeRows
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
						QuietLink(
							title: "Learn more",
							destination: URL(
								string:
									"https://github.com/LuMiSxh/Arknights-MacOS-Client/blob/main/docs/ai-assistance.md"
							)!
						)
					}
					.font(.caption)
				}
			}
		}
	}

	private var appVersion: String { IssueReportURL.appVersion }

	@ViewBuilder
	private var runtimeRows: some View {
		if let runtime {
			SettingsActionRow(title: "Version") {
				valueText(runtime.name)
			}
			SettingsHairline()
			SettingsActionRow(title: "Architecture") {
				valueText(runtime.architecture)
			}
			SettingsHairline()
			// Not a stack: the panel pads and divides each top-level row, including the expanded ones.
			Group {
				Button {
					withAnimation(LauncherMotion.animation(.disclosure, reduceMotion: reduceMotion))
					{
						isShowingTechnicalDetails.toggle()
					}
				} label: {
					HStack {
						Text("Technical details")
							.foregroundStyle(theme.textPrimary)
						Spacer(minLength: 0)
						Image(systemName: "chevron.right")
							.font(.caption.weight(.medium))
							.foregroundStyle(theme.textSecondary)
							.rotationEffect(.degrees(isShowingTechnicalDetails ? 90 : 0))
							.accessibilityHidden(true)
					}
					.contentShape(.rect)
				}
				.buttonStyle(.plain)
				.accessibilityValue(isShowingTechnicalDetails ? "Expanded" : "Collapsed")
				if isShowingTechnicalDetails {
					SettingsHairline()
					SettingsActionRow(
						title: "Wine",
						detail: runtime.wineCommit.map { "Commit \($0.prefix(12))" }
					) {
						valueText(runtime.wineVersion ?? "—")
					}
					SettingsHairline()
					SettingsActionRow(
						title: "DXMT",
						detail: runtime.dxmtCommit.map { "Commit \($0.prefix(12))" }
					) {
						valueText(runtime.dxmtVersion ?? "—")
					}
					SettingsHairline()
					capabilityRow("Hardware cursor", advertised: runtime.hardwareCursor)
					SettingsHairline()
					capabilityRow(
						"MetalFX spatial upscaling", advertised: runtime.metalFXSpatialUpscaling)
					SettingsHairline()
					capabilityRow(
						"Native fullscreen Space", advertised: runtime.nativeFullscreenSpace)
				}
			}
		} else {
			SettingsActionRow(title: "Version") {
				valueText("Not installed")
			}
		}
	}

	private func capabilityRow(_ title: String, advertised: Bool) -> some View {
		SettingsActionRow(title: title) {
			valueText(advertised ? "Advertised" : "Not advertised")
		}
	}

	private func valueText(_ text: String) -> some View {
		Text(text)
			.foregroundStyle(theme.textSecondary)
	}

	@ViewBuilder
	private var identitySummary: some View {
		HStack(alignment: .center, spacing: LauncherTokens.Spacing.content) {
			Image(nsImage: launcherIconManager.currentIcon)
				.resizable()
				.frame(width: 76, height: 76)
				.accessibilityHidden(true)
			VStack(alignment: .leading, spacing: LauncherTokens.Spacing.control) {
				Text("Unofficial macOS launcher")
					.foregroundStyle(theme.textSecondary)
				QuietLink(title: "LuMiSxh", destination: URL(string: "https://github.com/LuMiSxh")!)
					.font(.callout.weight(.medium))
			}
		}
	}

	@ViewBuilder
	private var identityActions: some View {
		HStack(spacing: LauncherTokens.Spacing.control) {
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
			systemImage: systemImage
		) {
			presentedDocument = document
		}
	}

	/// Lists the documents once for both layouts. The inline row fills its width; the
	/// stacked list separates rows with hairlines.
	/// Lists the documents once for both layouts. The inline row fills its width; the
	/// stacked list separates rows with hairlines.
	@ViewBuilder
	private func documentLinks(isInline: Bool) -> some View {
		documentLink(
			.changelog, title: "Changelog",
			systemImage: "clock.arrow.circlepath"
		)
		.frame(maxWidth: isInline ? .infinity : nil)
		if !isInline { SettingsHairline() }
		documentLink(
			.projectLicense, title: "MPL-2.0 License",
			systemImage: "checkmark.seal"
		)
		.frame(maxWidth: isInline ? .infinity : nil)
		if !isInline { SettingsHairline() }
		documentLink(
			.thirdPartyNotices, title: "Third-Party Notices",
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
