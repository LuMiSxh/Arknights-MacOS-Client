// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct LauncherArtworkView: View {
	let image: NSImage?
	let themeCacheKey: String?
	let accentColor: Color
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		GeometryReader { proxy in
			ZStack {
				if let image {
					Image(nsImage: image)
						.resizable()
						.scaledToFill()
						.id(artworkIdentity)
						.transition(artworkTransition)
						.accessibilityLabel(LauncherStrings.artworkAccessibility)
				} else {
					fallbackArtwork
						.id(artworkIdentity)
						.transition(artworkTransition)
						.accessibilityHidden(true)
				}
			}
			.frame(width: proxy.size.width, height: proxy.size.height)
			.clipped()
			.animation(
				reduceMotion ? nil : .easeInOut(duration: 0.36),
				value: artworkIdentity
			)
		}
	}

	private var artworkIdentity: String {
		themeCacheKey ?? (image == nil ? "fallback" : "artwork")
	}

	private var artworkTransition: AnyTransition {
		reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.015))
	}

	private var fallbackArtwork: some View {
		ZStack {
			Color(red: 0.035, green: 0.04, blue: 0.045)
			Text("A")
				.font(.custom("Avenir Next Condensed", size: 440).weight(.black))
				.foregroundStyle(.white.opacity(0.07))
			Rectangle()
				.fill(accentColor.opacity(0.4))
				.frame(width: 620, height: 10)
				.rotationEffect(.degrees(-42))
		}
	}
}
