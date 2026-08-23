// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct LauncherArtworkView: View {
	let image: NSImage?
	let accentColor: Color
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		GeometryReader { proxy in
			ZStack {
				if let image {
					Image(nsImage: image)
						.resizable()
						.scaledToFill()
						.id(ObjectIdentifier(image))
						.transition(.opacity)
						.accessibilityLabel(LauncherStrings.artworkAccessibility)
				} else {
					fallbackArtwork
						.transition(.opacity)
				}
			}
			.frame(width: proxy.size.width, height: proxy.size.height)
			.clipped()
			.animation(
				reduceMotion ? nil : .easeInOut(duration: 0.36),
				value: image.map(ObjectIdentifier.init)
			)
		}
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
