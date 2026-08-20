// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Loads one bounded avatar asset and renders its coordinated Launcher and Game previews.
struct CachedPresetOperatorPair: View {
	let url: URL
	let cacheKey: String
	let accentHue: Double?

	@State private var icons: (launcher: NSImage, game: NSImage)?
	@State private var hasFailed = false

	var body: some View {
		Group {
			if let icons {
				HStack(spacing: 8) {
					preview(icons.launcher)
					preview(icons.game)
				}
			} else if hasFailed {
				Label("Icon previews unavailable", systemImage: "person.crop.square.fill")
					.labelStyle(.iconOnly)
					.font(.title2)
					.foregroundStyle(.tertiary)
			} else {
				ProgressView()
					.controlSize(.small)
			}
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel("Launcher and game icon previews")
		.task(id: renderIdentifier) {
			icons = nil
			hasFailed = false
			do {
				let data = try await PresetCatalogService.shared.imageData(
					for: url,
					cacheKey: cacheKey
				)
				guard !Task.isCancelled,
					let rendered = AppIconRenderer.createPresetIconPair(
						from: data,
						accentHue: accentHue
					)
				else { return }
				icons = rendered
			} catch {
				hasFailed = true
			}
		}
	}

	private func preview(_ image: NSImage) -> some View {
		Image(nsImage: image)
			.resizable()
			.aspectRatio(contentMode: .fit)
			.frame(width: 78, height: 78)
	}

	private var renderIdentifier: String {
		"\(url.absoluteString)|\(accentHue ?? -1)"
	}
}
