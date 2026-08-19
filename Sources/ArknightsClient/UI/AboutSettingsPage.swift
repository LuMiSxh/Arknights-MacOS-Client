// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct AboutSettingsPage: View {
	var model: LauncherViewModel
	@Binding var presentedDocument: BundledDocument?

	var body: some View {
		SettingsPage(
			title: "About", subtitle: "Arknights Client \(appVersion)",
			accentColor: model.accentColor
		) {
			HStack(alignment: .center, spacing: 18) {
				Image(nsImage: NSApplication.shared.applicationIconImage)
					.resizable()
					.frame(width: 76, height: 76)
				VStack(alignment: .leading, spacing: 5) {
					Text("Arknights Client")
						.font(.title2.bold())
					Text("Unofficial macOS launcher")
						.foregroundStyle(.secondary)
					AccentLink(
						title: "LuMiSxh", destination: URL(string: "https://github.com/LuMiSxh")!,
						accentColor: model.accentColor
					)
					.font(.callout.weight(.medium))
				}
				Spacer()
				Button("Show in Finder", systemImage: "folder", action: model.revealApplication)
					.labelStyle(.iconOnly)
					.adaptiveGlassButton()
					.help("Reveal the launcher application in Finder")
				Link(
					"GitHub Repository",
					destination: URL(
						string: "https://github.com/LuMiSxh/Arknights-MacOS-Client")!
				)
				.adaptiveGlassButton()
				.foregroundStyle(.primary)
			}
			.padding(20)
			.adaptiveGlassEffect(in: .rect(cornerRadius: 20))

			SettingsPanel(title: "Documents", systemImage: "doc.text") {
				DocumentLinkRow(
					title: "Changelog", systemImage: "clock.arrow.circlepath",
					accentColor: model.accentColor
				) {
					presentedDocument = .changelog
				}
				SettingsHairline()
				DocumentLinkRow(
					title: "MPL-2.0 License", systemImage: "checkmark.seal",
					accentColor: model.accentColor
				) {
					presentedDocument = .projectLicense
				}
				SettingsHairline()
				DocumentLinkRow(
					title: "Third-Party Notices", systemImage: "shippingbox",
					accentColor: model.accentColor
				) {
					presentedDocument = .thirdPartyNotices
				}
			}

			SettingsPanel(title: "Arknights", systemImage: "link") {
				HStack(spacing: 18) {
					if let agreement = model.branding?.userAgreement {
						AccentLink(
							title: "User Agreement", destination: agreement,
							accentColor: model.accentColor
						)
					}
					if let privacy = model.branding?.privacyPolicy {
						AccentLink(
							title: "Privacy Policy", destination: privacy,
							accentColor: model.accentColor
						)
					}
					Spacer()
					Text("This launcher is not affiliated with Hypergryph or Yostar.")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
		}
	}

	private var appVersion: String { IssueReportURL.appVersion }
}
