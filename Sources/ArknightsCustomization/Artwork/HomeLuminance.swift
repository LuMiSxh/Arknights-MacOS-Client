// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import SwiftUI

// Pure math behind the Home controls' tone. It has no AppKit dependency, so the scan can run
// off the main actor.
nonisolated enum HomeLuminance {
	// `pixels` holds RGBA bytes for a `side` x `side` square, with row 0 at the top. Returns nil
	// when no pixel is opaque. A median, not a mean, keeps a few bright highlights from flipping
	// the result.
	static func score(pixels: [UInt8], side: Int) -> Double? {
		guard side > 0, pixels.count >= side * side * 4 else { return nil }
		let regions = AppConstants.Theme.homeControlRegions
		var frame: [Double] = []
		var controls: [Double] = []
		for row in 0..<side {
			for column in 0..<side {
				let offset = (row * side + column) * 4
				guard pixels[offset + 3] >= 128 else { continue }
				let luminance = linearLuminance(
					red: pixels[offset], green: pixels[offset + 1], blue: pixels[offset + 2])
				frame.append(luminance)
				let center = CGPoint(
					x: (Double(column) + 0.5) / Double(side),
					y: (Double(row) + 0.5) / Double(side))
				if regions.contains(where: { $0.contains(center) }) {
					controls.append(luminance)
				}
			}
		}
		guard let frameMedian = median(of: frame) else { return nil }
		let controlMedian = median(of: controls) ?? frameMedian
		let overall = AppConstants.Theme.homeLuminanceOverallWeight
		let control = AppConstants.Theme.homeLuminanceControlWeight
		let mixed =
			overall * perceptualLightness(frameMedian)
			+ control * perceptualLightness(controlMedian)
		return mixed / (overall + control)
	}

	// Above the light threshold the scheme is light, below the dark threshold it is dark, and in
	// between it keeps `previous`.
	static func colorScheme(for score: Double, previous: ColorScheme) -> ColorScheme {
		if score > AppConstants.Theme.lightHomeLuminanceThreshold { return .light }
		if score < AppConstants.Theme.darkHomeLuminanceThreshold { return .dark }
		return previous
	}

	// Rec. 709 weights applied to linear light.
	private static func linearLuminance(red: UInt8, green: UInt8, blue: UInt8) -> Double {
		0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
	}

	// The sRGB transfer function, IEC 61966-2-1.
	private static func linear(_ channel: UInt8) -> Double {
		let encoded = Double(channel) / 255
		return encoded <= 0.04045 ? encoded / 12.92 : pow((encoded + 0.055) / 1.055, 2.4)
	}

	// CIE L*, scaled to 0 to 1, so the thresholds compare against perceptual lightness.
	private static func perceptualLightness(_ luminance: Double) -> Double {
		let lightness =
			luminance <= 216.0 / 24389.0
			? luminance * 24389.0 / 27.0 : 116 * cbrt(luminance) - 16
		return min(max(lightness / 100, 0), 1)
	}

	private static func median(of values: [Double]) -> Double? {
		guard !values.isEmpty else { return nil }
		let sorted = values.sorted()
		let middle = sorted.count / 2
		guard sorted.count.isMultiple(of: 2) else { return sorted[middle] }
		return (sorted[middle - 1] + sorted[middle]) / 2
	}
}
