// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsCustomization
import SwiftUI

struct LauncherArtworkView: View {
	@Environment(\.launcherTheme) private var theme
	let background: HeroBackground?
	let themeCacheKey: String?
	let accentColor: Color
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.decorativeMotionEnabled) private var decorativeMotionEnabled
	// The very first artwork this view ever shows is revealed instantly (it was loaded while
	// the window was still covered) — only later live updates get the crossfade.
	@State private var hasShownArtworkBefore = false

	var body: some View {
		GeometryReader { proxy in
			ZStack {
				artwork
					.id(artworkIdentity)
					.transition(artworkTransition)
			}
			.frame(width: proxy.size.width, height: proxy.size.height)
			.clipped()
			.animation(
				hasShownArtworkBefore
					? LauncherMotion.animation(.crossfade, reduceMotion: reduceMotion) : nil,
				value: artworkIdentity
			)
			.onChange(of: artworkIdentity, initial: true) { _, _ in
				if background != nil { hasShownArtworkBefore = true }
			}
		}
	}

	private var artworkIdentity: String {
		themeCacheKey ?? (background == nil ? "fallback" : "artwork")
	}

	@ViewBuilder
	private var artwork: some View {
		switch background {
		case .image(let image)?:
			Image(nsImage: image)
				.resizable()
				.scaledToFill()
				.accessibilityLabel("Arknights artwork")
		case .video(let url, let poster)?:
			ZStack {
				Image(nsImage: poster)
					.resizable()
					.scaledToFill()
				// Same gate as ContinuousMotion: the video runs only while decorative motion does.
				LauncherVideoBackground(
					url: url, isPlaying: decorativeMotionEnabled && !reduceMotion
				)
				.accessibilityHidden(true)
			}
			.accessibilityLabel("Arknights artwork")
		case nil:
			fallbackArtwork
				.accessibilityHidden(true)
		}
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
