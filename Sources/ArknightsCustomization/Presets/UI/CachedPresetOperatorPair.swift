// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct CachedPresetOperatorPair: View {
	let catalog: PresetCatalogService
	let url: URL
	package let cacheKey: String
	let accentHue: Double?
	var iconDimension: CGFloat = 82
	var itemWidth: CGFloat = 104

	@State private var icons: (launcher: NSImage, game: NSImage)?
	@State private var hasFailed = false

	var body: some View {
		Group {
			if let icons {
				HStack(spacing: 16) {
					preview(icons.launcher)
					preview(icons.game)
				}
			} else if hasFailed {
				Label(
					"Icon previews unavailable",
					systemImage: "person.crop.square.fill"
				)
				.labelStyle(.iconOnly)
				.font(.title2)
				.foregroundStyle(.tertiary)
			} else {
				ProgressView()
					.controlSize(.small)
			}
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(
			"Launcher and game icon previews"
		)
		.task(id: renderIdentifier) {
			let taskIdentifier = renderIdentifier
			guard !Task.isCancelled else { return }
			if let cached = PresetThumbnailCache.shared.iconPair(
				cacheKey: cacheKey,
				accentHue: accentHue
			) {
				icons = (cached.launcher, cached.game)
				hasFailed = false
				return
			}
			icons = nil
			hasFailed = false
			do {
				let data = try await catalog.imageData(
					for: url,
					cacheKey: cacheKey
				)
				guard !Task.isCancelled, renderIdentifier == taskIdentifier else { return }
				let rendered = await PresetThumbnailCache.shared.renderIconPair(
					from: data,
					cacheKey: cacheKey,
					accentHue: accentHue
				)
				guard !Task.isCancelled, renderIdentifier == taskIdentifier else { return }
				guard let rendered else {
					hasFailed = true
					return
				}
				icons = (rendered.launcher, rendered.game)
			} catch is CancellationError {
				return
			} catch {
				guard !Task.isCancelled, renderIdentifier == taskIdentifier else { return }
				hasFailed = true
			}
		}
	}

	private func preview(_ image: NSImage) -> some View {
		Image(nsImage: image)
			.resizable()
			.aspectRatio(contentMode: .fit)
			.frame(width: iconDimension, height: iconDimension)
			.frame(width: itemWidth)
	}

	private var renderIdentifier: String {
		"\(url.absoluteString)|\(cacheKey)|\(accentHue ?? -1)"
	}
}
