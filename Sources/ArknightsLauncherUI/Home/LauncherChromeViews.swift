// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

struct ArknightsWordmark: View {
	let logo: NSImage?
	package let region: GameRegion
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.colorScheme) private var colorScheme

	var body: some View {
		ZStack(alignment: .leading) {
			if let logo {
				officialLogo(logo)
					.id(wordmarkIdentity)
					.transition(wordmarkTransition)
			} else {
				Text(wordmarkFallback)
					.font(LauncherVisuals.Typography.wordmark)
					.minimumScaleFactor(0.7)
					.lineLimit(1)
					.id(wordmarkIdentity)
					.transition(wordmarkTransition)
			}
		}
		.frame(width: 244, height: 68, alignment: .leading)
		.shadow(color: .black.opacity(0.46), radius: 9, y: 3)
		.padding(.trailing, 24)
		.animation(wordmarkAnimation, value: wordmarkIdentity)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(
			"Arknights \(region.displayName) macOS client"
		)
	}

	private var isLightScheme: Bool { colorScheme == .light }

	/// The logo source color depends on the publisher. Invert it when that color differs from the
	/// home scheme's foreground: white on the dark home, black on the light home.
	@ViewBuilder
	private func officialLogo(_ logo: NSImage) -> some View {
		let image = Image(nsImage: logo).resizable().scaledToFit()
		if (region.publisher != .yostar) != isLightScheme {
			image.colorInvert()
		} else {
			image
		}
	}

	private var wordmarkFallback: String {
		switch region {
		case .global: "ARKNIGHTS · GLOBAL"
		case .japan: "ARKNIGHTS · JAPAN"
		case .korea: "ARKNIGHTS · KOREA"
		case .taiwan: "ARKNIGHTS · TAIWAN"
		case .china: "ARKNIGHTS · CHINA"
		case .chinaBilibili: "ARKNIGHTS · CHINA · BILIBILI"
		}
	}

	private var wordmarkIdentity: String {
		"\(region.rawValue).\(logo == nil ? "fallback" : "official").\(isLightScheme ? "light" : "dark")"
	}

	private var wordmarkAnimation: Animation? {
		LauncherMotion.animation(.crossfade, reduceMotion: reduceMotion)
	}

	private var wordmarkTransition: AnyTransition {
		reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98))
	}
}

struct LauncherPopupView: View {
	let popup: LauncherPopup
	package let accentColor: Color

	let dismiss: () -> Void
	let openAction: () -> Void
	@State private var contentHeight: CGFloat = 0

	var body: some View {
		ThemedModalView(
			title: popup.title,

			width: 620,
			height: popupHeight
		) {
			Group {
				switch popup.content {
				case .markdown(let source):
					MarkdownDocument(source: source)
				case .attributed(let content):
					Text(content)
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.onGeometryChange(for: CGFloat.self) { proxy in
				proxy.size.height
			} action: { newHeight in
				contentHeight = newHeight
			}
			.textSelection(.enabled)
			.pointerStyle(.default)
		} actions: {
			if let actionTitle = popup.actionTitle {
				CapsuleActionButton(
					title: actionTitle,
					tone: .accent(accentColor),
					action: openAction
				)
				.keyboardShortcut(.defaultAction)

				CapsuleActionButton(
					title: popup.dismissTitle, tone: .neutral, action: dismiss
				)
			} else {
				FloatingDoneButton(
					title: popup.dismissTitle,
					accentColor: accentColor,
					action: dismiss
				)
			}
		}
	}

	private var popupHeight: CGFloat {
		guard contentHeight > 0 else { return 430 }
		return min(max(contentHeight + 160, 320), 600)
	}
}
