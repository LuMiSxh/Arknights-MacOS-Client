// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct ArknightsWordmark: View {
	let logo: NSImage?
	let region: GameRegion
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency

	var body: some View {
		ZStack(alignment: .leading) {
			// Keep official wallpaper logos from competing with the launcher wordmark
			// without introducing another card or glass surface.
			wordmarkBacking

			if let logo {
				Image(nsImage: logo)
					.resizable()
					.scaledToFit()
					.id(wordmarkIdentity)
					.transition(wordmarkTransition)
			} else {
				Text(L10n.string(HomeStrings.wordmarkFallback(region: region)))
					.font(.system(.title, design: .serif))
					.minimumScaleFactor(0.7)
					.lineLimit(1)
					.id(wordmarkIdentity)
					.transition(wordmarkTransition)
			}
		}
		.frame(width: 245, height: 69, alignment: .leading)
		.shadow(color: .black.opacity(0.46), radius: 9, y: 3)
		.padding(.trailing, 24)
		.animation(wordmarkAnimation, value: wordmarkIdentity)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(
			L10n.string(HomeStrings.wordmarkAccessibility(region: region.localizedDisplayName))
		)
	}

	private var wordmarkIdentity: String {
		"\(region.rawValue).\(logo == nil ? "fallback" : "official")"
	}

	private var wordmarkAnimation: Animation? {
		reduceMotion ? nil : .easeInOut(duration: 0.28)
	}

	@ViewBuilder
	private var wordmarkBacking: some View {
		if reduceTransparency {
			Ellipse()
				.fill(.black.opacity(0.62))
				.frame(width: 292, height: 88)
				.offset(x: -12, y: 3)
		} else {
			Ellipse()
				.fill(.black.opacity(0.34))
				.frame(width: 292, height: 88)
				.blur(radius: 17)
				.offset(x: -12, y: 3)
		}
	}

	private var wordmarkTransition: AnyTransition {
		reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98))
	}
}

struct LauncherPopupView: View {
	let popup: LauncherPopup
	let accentColor: Color
	let hudTintColor: Color
	let dismiss: () -> Void
	let openAction: () -> Void
	@State private var contentHeight: CGFloat = 0

	var body: some View {
		ThemedModalView(
			title: popup.title,
			accentColor: accentColor,
			hudTintColor: hudTintColor,
			width: 620,
			height: popupHeight
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
			.onGeometryChange(for: CGFloat.self) { proxy in
				proxy.size.height
			} action: { newHeight in
				contentHeight = newHeight
			}
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
