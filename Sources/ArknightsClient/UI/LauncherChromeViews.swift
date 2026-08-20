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
	let accentTextColor: Color
	let hudTintColor: Color
	let dismiss: () -> Void
	let openAction: () -> Void

	var body: some View {
		LauncherThemedPopup(
			title: popup.title,
			hudTintColor: hudTintColor
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
			HStack(spacing: 10) {
				if let actionTitle = popup.actionTitle {
					Button(action: openAction) {
						Text(actionTitle)
							.foregroundStyle(accentTextColor)
					}
					.adaptiveGlassCapsuleButton()
					.tint(accentColor)
					.keyboardShortcut(.defaultAction)

					Button(action: dismiss) {
						Text(popup.dismissTitle)
							.foregroundStyle(accentTextColor)
					}
					.adaptiveGlassCapsuleButton(prominent: true)
					.tint(accentColor)
				} else {
					Button(action: dismiss) {
						Text(popup.dismissTitle)
							.foregroundStyle(accentTextColor)
					}
					.adaptiveGlassCapsuleButton(prominent: true)
					.tint(accentColor)
					.keyboardShortcut(.defaultAction)
				}
			}
		}
	}
}

private struct LauncherThemedPopup<Content: View, Actions: View>: View {
	let title: String
	let hudTintColor: Color
	@ViewBuilder let content: () -> Content
	@ViewBuilder let actions: () -> Actions

	var body: some View {
		ZStack(alignment: .bottomTrailing) {
			VStack(spacing: 0) {
				Text(title)
					.font(.title2.bold())
					.padding(.horizontal, 24)
					.padding(.top, 22)
					.padding(.bottom, 16)

				SettingsHairline()

				ScrollView {
					content()
						.padding(.horizontal, 24)
						.padding(.vertical, 18)
				}
				.contentMargins(.top, 8, for: .scrollIndicators)
				.contentMargins(.bottom, 12, for: .scrollIndicators)
				.scrollIndicators(.automatic)
			}

			// Soft bottom gradient scrim
			LinearGradient(
				colors: [.clear, Color.black.opacity(0.45)],
				startPoint: .top,
				endPoint: .bottom
			)
			.frame(height: 56)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
			.allowsHitTesting(false)

			HStack(spacing: 10) {
				actions()
			}
			.padding(.trailing, 24)
			.padding(.bottom, 18)
		}
		.frame(width: 620, height: 430)
		.background(
			ZStack {
				Color(red: 0.07, green: 0.07, blue: 0.08)
				hudTintColor
			}
		)
		.preferredColorScheme(.dark)
	}
}
