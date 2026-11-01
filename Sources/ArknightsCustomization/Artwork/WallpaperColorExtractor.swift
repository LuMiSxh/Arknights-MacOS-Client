// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import SwiftUI

// The accent color taken from artwork; neutrals stay graphite and never take its hue.
struct ExtractedAccent: Sendable {
	let hue: Double
	let saturation: Double
	let brightness: Double
	package let accentColor: Color

	init(hue: Double, saturation: Double, brightness: Double) {
		self.hue = hue
		self.saturation = saturation
		self.brightness = brightness
		accentColor = Color(hue: hue, saturation: saturation, brightness: brightness)
	}
}

// The thumbnail is drawn on the main actor because AppKit drawing is not thread-safe.
// The pixel scan runs off the main actor so synchronous image work stays off the UI.
@MainActor
enum WallpaperColorExtractor {
	// Returns nil when no sampled pixel has a real hue (grayscale or near-black artwork).
	// Callers then use the fixed cyan. Otherwise the accent keeps the artwork's dominant OKLCH
	// hue at a fixed perceptual lightness, so dark, pale, and neon artwork all yield a calm accent.
	static func extractAccent(from image: NSImage) async -> ExtractedAccent? {
		guard let pixels = samplePixels(from: image) else { return nil }
		return await bestAccentColor(in: pixels)
	}

	private static func samplePixels(from image: NSImage) -> [UInt8]? {
		let side = AppConstants.Theme.wallpaperSampleSide
		let bounds = NSRect(x: 0, y: 0, width: side, height: side)
		guard
			let bitmap = RGBABitmap.render(
				pixelsWide: side,
				pixelsHigh: side,
				size: bounds.size,
				draw: { _ in image.draw(in: bounds, from: .zero, operation: .copy, fraction: 1) }
			)
		else { return nil }

		guard let data = bitmap.bitmapData else { return nil }
		return Array(UnsafeBufferPointer(start: data, count: side * side * 4))
	}
}

// Pure pixel math with no AppKit dependency; `@concurrent` keeps the scan off the main actor.
@concurrent
private func bestAccentColor(in pixels: [UInt8]) async -> ExtractedAccent? {
	let side = AppConstants.Theme.wallpaperSampleSide
	let bucketCount = AppConstants.Theme.accentHueBuckets
	var buckets = [HueBucket](repeating: HueBucket(), count: bucketCount)

	for pixel in 0..<(side * side) {
		let offset = pixel * 4
		guard offset + 3 < pixels.count else { continue }
		let alpha = Double(pixels[offset + 3]) / 255
		guard alpha > 0.5 else { continue }

		let lab = OKLab(
			red: Double(pixels[offset]) / 255,
			green: Double(pixels[offset + 1]) / 255,
			blue: Double(pixels[offset + 2]) / 255
		)
		guard
			lab.chroma >= AppConstants.Theme.minimumPixelChroma,
			lab.lightness >= AppConstants.Theme.minimumPixelLightness,
			lab.lightness <= AppConstants.Theme.maximumPixelLightness
		else { continue }

		let bucket = min(bucketCount - 1, Int(lab.hue * Double(bucketCount)))
		buckets[bucket].add(.sample(lab))
	}

	// A hue cluster that straddles a bucket edge (red at 0°/360°) would split its score across
	// two buckets. Scoring each bucket with its circular neighbors keeps the cluster whole.
	let windows = buckets.indices.map { center in
		var window = HueBucket()
		for neighbor in [center - 1, center, center + 1] {
			window.add(buckets[(neighbor + bucketCount) % bucketCount])
		}
		return window
	}
	guard
		let winner = windows.indices.max(by: { windows[$0].weight < windows[$1].weight }),
		windows[winner].weight > 0
	else { return nil }

	let window = windows[winner]
	// The circular mean is the angle of the summed unit vectors. Shifting by one turn before
	// wrapping keeps the result in [0, 1) when the angle is negative.
	let turns = atan2(window.sine, window.cosine) / (2 * .pi)
	let hue = (turns + 1).truncatingRemainder(dividingBy: 1)
	let chroma = min(
		max(window.chroma / window.weight, AppConstants.Theme.minimumAccentChroma),
		AppConstants.Theme.maximumAccentChroma
	)
	let rgb = OKLab.gamutMappedRGB(
		lightness: AppConstants.Theme.accentLightness,
		chroma: chroma,
		hue: hue
	)
	// Callers rotate icons and tint neutrals by HSB hue, so report the rendered color in HSB.
	let rendered = hsb(red: rgb.red, green: rgb.green, blue: rgb.blue)
	return ExtractedAccent(
		hue: rendered.hue,
		saturation: rendered.saturation,
		brightness: rendered.brightness
	)
}

// Hue is stored as a weighted unit vector (cosine and sine), so a hue window that crosses
// 0°/360° still averages correctly.
private struct HueBucket {
	var weight = 0.0
	var cosine = 0.0
	var sine = 0.0
	var chroma = 0.0

	// Weighting by chroma² lets a small vivid accent beat a large muted area.
	static func sample(_ lab: OKLab) -> HueBucket {
		let weight = lab.chroma * lab.chroma
		let angle = 2 * Double.pi * lab.hue
		return HueBucket(
			weight: weight,
			cosine: weight * cos(angle),
			sine: weight * sin(angle),
			chroma: weight * lab.chroma
		)
	}

	mutating func add(_ other: HueBucket) {
		weight += other.weight
		cosine += other.cosine
		sine += other.sine
		chroma += other.chroma
	}
}

// Björn Ottosson's OKLab: perceptually even lightness and chroma, unlike HSB, where yellow at
// full brightness glares and blue at full brightness still looks dark.
private struct OKLab {
	let lightness: Double
	let a: Double
	let b: Double

	var chroma: Double { (a * a + b * b).squareRoot() }
	/// Hue in turns, [0, 1).
	var hue: Double {
		let turns = atan2(b, a) / (2 * .pi)
		return (turns + 1).truncatingRemainder(dividingBy: 1)
	}

	init(red: Double, green: Double, blue: Double) {
		let r = Self.linear(red)
		let g = Self.linear(green)
		let b = Self.linear(blue)
		let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
		let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
		let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
		lightness = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
		a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
		self.b = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
	}

	/// The sRGB color at this lightness and hue, with chroma reduced until it fits the gamut.
	static func gamutMappedRGB(
		lightness: Double, chroma: Double, hue: Double
	) -> (red: Double, green: Double, blue: Double) {
		let angle = 2 * Double.pi * hue
		func rgb(_ chroma: Double) -> (red: Double, green: Double, blue: Double)? {
			let a = chroma * cos(angle)
			let b = chroma * sin(angle)
			let l = pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3)
			let m = pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3)
			let s = pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3)
			let red = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
			let green = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
			let blue = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
			let channels = [red, green, blue]
			guard channels.allSatisfy({ $0 >= -0.0001 && $0 <= 1.0001 }) else { return nil }
			return (encoded(red), encoded(green), encoded(blue))
		}
		if let color = rgb(chroma) { return color }
		var low = 0.0
		var high = chroma
		for _ in 0..<16 {
			let middle = (low + high) / 2
			if rgb(middle) == nil { high = middle } else { low = middle }
		}
		return rgb(low) ?? (lightness, lightness, lightness)
	}

	private static func linear(_ channel: Double) -> Double {
		channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
	}

	private static func encoded(_ channel: Double) -> Double {
		let clamped = min(max(channel, 0), 1)
		return clamped <= 0.0031308
			? 12.92 * clamped : 1.055 * pow(clamped, 1 / 2.4) - 0.055
	}
}

private func hsb(
	red: Double, green: Double, blue: Double
) -> (
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
