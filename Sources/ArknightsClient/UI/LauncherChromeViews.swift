// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct ArknightsWordmark: View {
	let logo: NSImage?
	let cyan: Color

	var body: some View {
		VStack(alignment: .leading, spacing: 9) {
			Group {
				if let logo {
					Image(nsImage: logo)
						.resizable()
						.scaledToFit()
				} else {
					Text("ARKNIGHTS")
						.font(.system(size: 32, weight: .regular, design: .serif))
				}
			}
			.frame(width: 245, height: 69, alignment: .leading)
			.shadow(color: .black.opacity(0.46), radius: 9, y: 3)

			HStack(spacing: 10) {
				Rectangle().fill(cyan).frame(width: 66, height: 3)
				Rectangle().fill(.white.opacity(0.34)).frame(width: 66, height: 3)
				Rectangle().fill(.white.opacity(0.16)).frame(width: 66, height: 3)
			}
		}
		.padding(.trailing, 24)
		.background {
			RadialGradient(
				colors: [.black.opacity(0.58), .black.opacity(0)],
				center: .leading,
				startRadius: 12,
				endRadius: 185
			)
			.frame(width: 320, height: 130)
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel("Arknights Global macOS client")
	}
}

struct LauncherPopupView: View {
	let popup: LauncherPopup
	let accentColor: Color
	let dismiss: () -> Void
	let openAction: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			Text(popup.title)
				.font(.title2.bold())
				.padding(.bottom, 16)
			SettingsHairline()
			ScrollView {
				Group {
					switch popup.content {
					case .markdown(let source):
						MarkdownDocument(source: source, accentColor: accentColor)
					case .attributed(let content):
						Text(content)
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.textSelection(.enabled)
				.padding(.vertical, 18)
			}
			SettingsHairline()
			HStack {
				Spacer()
				if let actionTitle = popup.actionTitle {
					Button(popup.dismissTitle, action: dismiss)
					Button(actionTitle, action: openAction)
						.buttonStyle(.glassProminent)
						.tint(accentColor)
						.keyboardShortcut(.defaultAction)
				} else {
					Button(popup.dismissTitle, action: dismiss)
						.buttonStyle(.glassProminent)
						.tint(accentColor)
						.keyboardShortcut(.defaultAction)
				}
			}
			.padding(.top, 14)
		}
		.padding(24)
		.frame(width: 560, height: 380)
		.background(.thinMaterial)
	}
}
