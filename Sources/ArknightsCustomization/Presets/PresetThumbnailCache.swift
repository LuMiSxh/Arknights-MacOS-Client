// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ImageIO
import SwiftUI

// In-memory gallery cache so a cell that scrolls back into view skips the on-disk catalog
// round trip, the thumbnail decode, and the icon render. `NSCache` is thread-safe and evicts
// under memory pressure.
final class PresetThumbnailCache: @unchecked Sendable {
	static let shared = PresetThumbnailCache()

	private let thumbnails = NSCache<NSString, CGImage>()
	private let iconPairs = NSCache<NSString, RenderedIconPair>()

	init() {
		thumbnails.totalCostLimit = AppConstants.Presets.thumbnailCacheMaximumBytes
		iconPairs.totalCostLimit = AppConstants.Presets.iconPairCacheMaximumBytes
	}

	func thumbnail(cacheKey: String, maxPixelSize: CGFloat) -> CGImage? {
		thumbnails.object(forKey: Self.thumbnailKey(cacheKey, maxPixelSize))
	}

	// Decodes straight to a bounded-size bitmap via ImageIO's thumbnail generator instead of
	// `NSImage(data:)`, which would decode the source at its full native resolution first.
	@concurrent
	func decodeThumbnail(
		from data: Data,
		cacheKey: String,
		maxPixelSize: CGFloat
	) async -> CGImage? {
		guard !Task.isCancelled,
			let source = CGImageSourceCreateWithData(data as CFData, nil)
		else { return nil }
		let options: [CFString: Any] = [
			kCGImageSourceCreateThumbnailFromImageAlways: true,
			kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
			kCGImageSourceCreateThumbnailWithTransform: true,
		]
		guard
			let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
		else { return nil }
		thumbnails.setObject(
			thumbnail,
			forKey: Self.thumbnailKey(cacheKey, maxPixelSize),
			cost: thumbnail.bytesPerRow * thumbnail.height
		)
		return thumbnail
	}

	func iconPair(cacheKey: String, accentHue: Double?) -> RenderedIconPair? {
		iconPairs.object(forKey: Self.iconPairKey(cacheKey, accentHue))
	}

	@concurrent
	func renderIconPair(
		from data: Data,
		cacheKey: String,
		accentHue: Double?
	) async -> RenderedIconPair? {
		guard !Task.isCancelled,
			let pair = await AppIconRenderer.renderPresetIcons(from: data, accentHue: accentHue)
		else { return nil }
		let pixels = Int(AppConstants.Icon.canvasDimension * AppConstants.Icon.renderScale)
		iconPairs.setObject(
			pair,
			forKey: Self.iconPairKey(cacheKey, accentHue),
			cost: 2 * pixels * pixels * 4
		)
		return pair
	}

	private static func thumbnailKey(_ cacheKey: String, _ maxPixelSize: CGFloat) -> NSString {
		"\(cacheKey)|\(Int(maxPixelSize))" as NSString
	}

	private static func iconPairKey(_ cacheKey: String, _ accentHue: Double?) -> NSString {
		"\(cacheKey)|\(accentHue ?? -1)" as NSString
	}
}
