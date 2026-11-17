// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct LauncherArtworkView: View {
	@Environment(\.launcherTheme) private var theme
	let image: NSImage?
	let themeCacheKey: String?
	let accentColor: Color
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	// The very first artwork this view ever shows is revealed instantly (it was loaded while
	// the window was still covered) — only later live updates get the crossfade.
	@State private var hasShownArtworkBefore = false

	var body: some View {
		ZStack {
			if let image {
				Image(nsImage: image)
					.resizable()
					.scaledToFill()
					.id(artworkIdentity)
					.transition(artworkTransition)
					.accessibilityLabel("Arknights artwork")
			} else {
				fallbackArtwork
					.id(artworkIdentity)
					.transition(artworkTransition)
					.accessibilityHidden(true)
			}
		}
		.clipped()
		.animation(
			hasShownArtworkBefore
				? LauncherMotion.animation(.crossfade, reduceMotion: reduceMotion) : nil,
			value: artworkIdentity
		)
		.onChange(of: artworkIdentity, initial: true) { _, _ in
			if image != nil { hasShownArtworkBefore = true }
		}
	}

	private var artworkIdentity: String {
		themeCacheKey ?? (image == nil ? "fallback" : "artwork")
	}

	private var artworkTransition: AnyTransition {
		.materialize(reduceMotion: reduceMotion, scale: 1.03)
	}

	private static let fallbackStripeWidth: CGFloat = 620
	private static let fallbackStripeHeight: CGFloat = 8

	private var fallbackArtwork: some View {
		ZStack {
			theme.sheetSolid
			Text("A")
				.font(LauncherTokens.Typography.fallbackWordmark)
				.foregroundStyle(
					.white.opacity(LauncherVisuals.Shade.fallbackWordmarkOpacity))
			Rectangle()
				.fill(accentColor.opacity(0.4))
				.frame(width: Self.fallbackStripeWidth, height: Self.fallbackStripeHeight)
				.rotationEffect(.degrees(-42))
		}
	}
}
