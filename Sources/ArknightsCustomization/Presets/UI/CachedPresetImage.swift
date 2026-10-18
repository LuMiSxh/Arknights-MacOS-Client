// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct CachedPresetImage: View {
	let catalog: PresetCatalogService
	let url: URL
	package let cacheKey: String
	var contentMode: ContentMode = .fill
	var placeholderIcon: String = "photo"

	// Both call sites render into small grid cells (avatars at 104pt, wallpapers at 105pt
	// tall), but some official wallpapers have no distinct thumbnail from Yostar and no CDN
	// resize option, so the cache can hand back the full multi-thousand-pixel original.
	// Decoding straight to a bounded thumbnail keeps peak memory and decode cost down
	// regardless of source size, covering up to 3x Retina scaling with headroom.
	private static let maxDecodedPixelSize: CGFloat = 400

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
				SkeletonValue(cornerRadius: 0)
			}
		}
		.accessibilityHidden(true)
		.task(id: cacheIdentity) {
			let taskIdentity = cacheIdentity
			guard !Task.isCancelled else { return }
			if let cached = PresetThumbnailCache.shared.thumbnail(
				cacheKey: cacheKey,
				maxPixelSize: Self.maxDecodedPixelSize
			) {
				image = NSImage(cgImage: cached, size: .zero)
				hasFailed = false
				return
			}
			image = nil
			hasFailed = false
			do {
				let data = try await catalog.imageData(
					for: url,
					cacheKey: cacheKey
				)
				guard !Task.isCancelled, cacheIdentity == taskIdentity else { return }
				guard
					let thumbnail = await PresetThumbnailCache.shared.decodeThumbnail(
						from: data,
						cacheKey: cacheKey,
						maxPixelSize: Self.maxDecodedPixelSize
					)
				else {
					throw CustomizationError.invalidPresetImage(url)
				}
				guard !Task.isCancelled, cacheIdentity == taskIdentity else { return }
				image = NSImage(cgImage: thumbnail, size: .zero)
				hasFailed = false
			} catch is CancellationError {
				return
			} catch {
				guard !Task.isCancelled, cacheIdentity == taskIdentity else { return }
				hasFailed = true
			}
		}
	}

	private var cacheIdentity: String {
		"\(url.absoluteString)|\(cacheKey)"
	}
}
