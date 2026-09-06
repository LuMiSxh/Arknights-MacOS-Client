// SPDX-License-Identifier: MPL-2.0

import ImageIO
import SwiftUI

/// Loads a validated preset image through the bounded on-disk gallery cache.
struct CachedPresetImage: View {
	let catalog: PresetCatalogService
	let url: URL
	let cacheKey: String
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
				ZStack {
					Color.white.opacity(0.04)
					ProgressView()
						.controlSize(.small)
				}
			}
		}
		.accessibilityHidden(true)
		.task(id: cacheIdentity) {
			let taskIdentity = cacheIdentity
			guard !Task.isCancelled else { return }
			image = nil
			hasFailed = false
			do {
				let data = try await catalog.imageData(
					for: url,
					cacheKey: cacheKey
				)
				guard let loadedImage = Self.decodedThumbnail(from: data) else {
					throw LauncherError.invalidPresetImage(url)
				}
				guard !Task.isCancelled, cacheIdentity == taskIdentity else { return }
				image = loadedImage
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

	// Decodes straight to a bounded-size bitmap via ImageIO's own thumbnail generator instead
	// of NSImage(data:), which would decode the source at its full native resolution before
	// anything gets a chance to scale it down.
	private static func decodedThumbnail(from data: Data) -> NSImage? {
		guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
		let options: [CFString: Any] = [
			kCGImageSourceCreateThumbnailFromImageAlways: true,
			kCGImageSourceThumbnailMaxPixelSize: maxDecodedPixelSize,
			kCGImageSourceCreateThumbnailWithTransform: true,
		]
		guard
			let thumbnail = CGImageSourceCreateThumbnailAtIndex(
				source, 0, options as CFDictionary)
		else { return nil }
		return NSImage(cgImage: thumbnail, size: .zero)
	}
}
