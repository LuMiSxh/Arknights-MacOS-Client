// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Loads a validated preset image through the bounded on-disk gallery cache.
struct CachedPresetImage: View {
	let catalog: PresetCatalogService
	let url: URL
	let cacheKey: String
	var contentMode: ContentMode = .fill
	var placeholderIcon: String = "photo"

	@State private var image: NSImage?
	@State private var hasFailed = false

	var body: some View {
		Group {
			if let image {
				Image(nsImage: image)
					.resizable()
					.aspectRatio(contentMode: contentMode)
			} else if hasFailed {
				ZStack {
					Color.white.opacity(0.04)
					Image(systemName: placeholderIcon)
						.font(.title2)
						.foregroundStyle(Color.white.opacity(0.15))
				}
			} else {
				ZStack {
					Color.white.opacity(0.04)
					ProgressView()
						.controlSize(.small)
				}
			}
		}
		.accessibilityHidden(true)
		.task(id: url) {
			guard image == nil else { return }
			do {
				let data = try await catalog.imageData(
					for: url,
					cacheKey: cacheKey
				)
				guard let loadedImage = NSImage(data: data) else {
					throw LauncherError.invalidPresetImage(url)
				}
				image = loadedImage
				hasFailed = false
			} catch {
				hasFailed = true
			}
		}
	}
}
