// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

/// The dominant hue extracted from hero artwork, rendered two ways: a legible signal color
/// for controls/text, and the same hue desaturated and darkened for tinting neutral chrome.
struct ExtractedAccent {
	let hue: Double
	let saturation: Double
	let brightness: Double
	let accentColor: Color

	init(hue: Double, saturation: Double, brightness: Double) {
		self.hue = hue
		self.saturation = saturation
		self.brightness = brightness
		accentColor = Color(hue: hue, saturation: saturation, brightness: brightness)
	}

	var backgroundTint: Color {
		Color(
			hue: hue,
			saturation: AppConstants.Theme.backgroundTintSaturation,
			brightness: AppConstants.Theme.backgroundTintBrightness
		)
		.opacity(AppConstants.Theme.backgroundTintOpacity)
	}
}

/// Derives a vibrant accent color from the launcher's hero artwork for dynamic theming.
/// Drawing the thumbnail must stay on the main actor (AppKit drawing isn't thread-safe), but
/// the pixel scan itself runs on a background executor to keep synchronous image work off UI.
@MainActor
enum WallpaperColorExtractor {
	/// Returns `nil` when the sampled thumbnail has no pixel with any real hue (e.g.
	/// grayscale or near-black artwork) — callers fall back to the fixed Arknights cyan and
	/// the static HUD tint in that case. Otherwise the winning hue's saturation/brightness
	/// are clamped into a legible range, so any artwork — dark, pale, or neon — yields a
	/// readable accent.
	static func extractAccent(from image: NSImage) async -> ExtractedAccent? {
		guard let pixels = samplePixels(from: image) else { return nil }
		return await Task.detached(priority: .utility) {
			bestAccentColor(in: pixels)
		}.value
	}

	private static func samplePixels(from image: NSImage) -> [UInt8]? {
		let side = AppConstants.Theme.wallpaperSampleSide
		guard
			let bitmap = NSBitmapImageRep(
				bitmapDataPlanes: nil,
				pixelsWide: side,
				pixelsHigh: side,
				bitsPerSample: 8,
				samplesPerPixel: 4,
				hasAlpha: true,
				isPlanar: false,
				colorSpaceName: .deviceRGB,
				bytesPerRow: 0,
				bitsPerPixel: 0
			),
			let context = NSGraphicsContext(bitmapImageRep: bitmap)
		else { return nil }

		NSGraphicsContext.saveGraphicsState()
		NSGraphicsContext.current = context
		image.draw(
			in: NSRect(x: 0, y: 0, width: side, height: side),
			from: .zero,
			operation: .copy,
			fraction: 1
		)
		NSGraphicsContext.restoreGraphicsState()

		guard let data = bitmap.bitmapData else { return nil }
		return Array(UnsafeBufferPointer(start: data, count: side * side * 4))
	}
}

/// Pure pixel math with no AppKit dependency, so it can run on `Task.detached`'s background
/// executor without hopping back to the main actor.
private func bestAccentColor(in pixels: [UInt8]) -> ExtractedAccent? {
	let side = AppConstants.Theme.wallpaperSampleSide
	let bucketCount = AppConstants.Theme.accentHueBuckets
	var bucketScore = [Double](repeating: 0, count: bucketCount)
	var bucketHueSum = [Double](repeating: 0, count: bucketCount)
	var bucketSaturationSum = [Double](repeating: 0, count: bucketCount)
	var bucketBrightnessSum = [Double](repeating: 0, count: bucketCount)
	var bucketCounts = [Int](repeating: 0, count: bucketCount)

	for pixel in 0..<(side * side) {
		let offset = pixel * 4
		guard offset + 3 < pixels.count else { continue }
		let alpha = Double(pixels[offset + 3]) / 255
		guard alpha > 0.5 else { continue }

		let red = Double(pixels[offset]) / 255
		let green = Double(pixels[offset + 1]) / 255
		let blue = Double(pixels[offset + 2]) / 255
		let (hue, saturation, brightness) = hsb(red: red, green: green, blue: blue)

		guard
			saturation >= AppConstants.Theme.minimumPixelSaturation,
			brightness >= AppConstants.Theme.minimumPixelBrightness,
			brightness <= AppConstants.Theme.maximumPixelBrightness
		else { continue }

		let bucket = min(bucketCount - 1, Int(hue * Double(bucketCount)))
		bucketScore[bucket] += saturation * brightness
		bucketHueSum[bucket] += hue
		bucketSaturationSum[bucket] += saturation
		bucketBrightnessSum[bucket] += brightness
		bucketCounts[bucket] += 1
	}

	guard
		let winner = bucketScore.indices.max(by: { bucketScore[$0] < bucketScore[$1] }),
		bucketCounts[winner] > 0
	else { return nil }

	let count = Double(bucketCounts[winner])
	let renderSaturation = min(
		max(bucketSaturationSum[winner] / count, AppConstants.Theme.minimumRenderSaturation),
		AppConstants.Theme.maximumRenderSaturation
	)
	let renderBrightness = min(
		max(bucketBrightnessSum[winner] / count, AppConstants.Theme.minimumRenderBrightness),
		AppConstants.Theme.maximumRenderBrightness
	)
	let hue = bucketHueSum[winner] / count
	return ExtractedAccent(
		hue: hue,
		saturation: renderSaturation,
		brightness: renderBrightness
	)
}

private func hsb(red: Double, green: Double, blue: Double) -> (
	hue: Double, saturation: Double, brightness: Double
) {
	let maxValue = max(red, green, blue)
	let minValue = min(red, green, blue)
	let delta = maxValue - minValue
	let brightness = maxValue
	let saturation = maxValue == 0 ? 0 : delta / maxValue

	guard delta != 0 else { return (0, saturation, brightness) }

	var hue: Double
	switch maxValue {
	case red: hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
	case green: hue = (blue - red) / delta + 2
	default: hue = (red - green) / delta + 4
	}
	hue /= 6
	if hue < 0 { hue += 1 }
	return (hue, saturation, brightness)
}
