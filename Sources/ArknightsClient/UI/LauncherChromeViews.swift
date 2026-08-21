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
		.accessibilityElement(children: .ignore)
		.accessibilityLabel("Arknights Global macOS client")
	}
}

struct LauncherPopupView: View {
	let popup: LauncherPopup
	let accentColor: Color
	let hudTintColor: Color
	let dismiss: () -> Void
	let openAction: () -> Void

	var body: some View {
		ThemedModalView(
			title: popup.title,
			accentColor: accentColor,
			hudTintColor: hudTintColor,
			width: 620,
			height: 430
		) {
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
		} actions: {
			if let actionTitle = popup.actionTitle {
				CapsuleActionButton(
					title: actionTitle, tone: .neutral, action: openAction
				)
				.keyboardShortcut(.defaultAction)

				CapsuleActionButton(
					title: popup.dismissTitle, tone: .accent(accentColor), action: dismiss
				)
			} else {
				if popup.dismissTitle == "Done" {
					FloatingDoneButton(accentColor: accentColor, action: dismiss)
				} else {
					CapsuleActionButton(
						title: popup.dismissTitle, tone: .accent(accentColor), action: dismiss
					)
					.keyboardShortcut(.defaultAction)
				}
			}
		}
	}
}
