// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Loads one bounded avatar asset and renders the selected icon treatment for its preview.
struct CachedPresetAvatarIcon: View {
	let url: URL
	let cacheKey: String
	let style: AvatarIconStyle
	let accentHue: Double?

	@State private var image: NSImage?
	@State private var hasFailed = false

	var body: some View {
		Group {
			if let image {
				Image(nsImage: image)
					.resizable()
					.aspectRatio(contentMode: .fit)
			} else if hasFailed {
				Image(systemName: "person.crop.square.fill")
					.font(.title2)
					.foregroundStyle(.tertiary)
			} else {
				ProgressView()
					.controlSize(.small)
			}
		}
		.task(id: renderIdentifier) {
			image = nil
			hasFailed = false
			do {
				let data = try await PresetCatalogService.shared.imageData(
					for: url,
					cacheKey: cacheKey
				)
				guard !Task.isCancelled,
					let rendered = AppIconRenderer.createAvatarIcon(
						from: data,
						style: style,
						accentHue: accentHue
					)
				else { return }
				image = rendered
			} catch {
				hasFailed = true
			}
		}
	}

	private var renderIdentifier: String {
		"\(url.absoluteString)|\(style.rawValue)|\(accentHue ?? -1)"
	}
}
