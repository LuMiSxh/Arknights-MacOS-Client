// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import Foundation
import Testing

@testable import ArknightsCustomization

@MainActor
struct WallpaperColorExtractorTests {
	typealias Run = (red: UInt8, green: UInt8, blue: UInt8, count: Int)

	@Test(
		arguments: [
			// Two red halves (about 355° and 5°) sit in different buckets; each alone scores below
			// the green bucket, but together they outweigh it.
			[
				(red: 230, green: 0, blue: 19, count: 20),
				(red: 230, green: 19, blue: 0, count: 20),
				(red: 0, green: 230, blue: 27, count: 30),
			],
			// The muted blue has more pixels, but its saturation squared weight is far lower.
			[
				(red: 230, green: 0, blue: 19, count: 10),
				(red: 107, green: 117, blue: 153, count: 60),
			],
		] as [[Run]])
	func vividRedAccentWinsOverBucketSplitOrLargerMutedRuns(runs: [Run]) async throws {
		let image = try makeImage(runs: runs)

		let accent = try #require(await WallpaperColorExtractor.extractAccent(from: image))
		let circularDistanceToRed = min(accent.hue, 1 - accent.hue)
		#expect(circularDistanceToRed < 0.03)
	}

	private func makeImage(
		runs: [Run]
	) throws -> NSImage {
		let side = AppConstants.Theme.wallpaperSampleSide
		// Pixels after the last run keep alpha 0, so the extractor skips them.
		var pixels = [UInt8](repeating: 0, count: side * side * 4)
		var index = 0
		for run in runs {
			for _ in 0..<run.count {
				pixels[index * 4] = run.red
				pixels[index * 4 + 1] = run.green
				pixels[index * 4 + 2] = run.blue
				pixels[index * 4 + 3] = 255
				index += 1
			}
		}
		let bitmap = try #require(
			NSBitmapImageRep(
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
			)
		)
		let data = try #require(bitmap.bitmapData)
		data.update(from: pixels, count: pixels.count)
		let image = NSImage(size: NSSize(width: side, height: side))
		image.addRepresentation(bitmap)
		return image
	}
}
