// SPDX-License-Identifier: MPL-2.0

import AppKit
import CoreImage
import SwiftUI

/// Unified engine for generating, dynamically tinting, and grid-normalizing macOS application icons.
enum AppIconRenderer {
	/// Insets and centers full-bleed icon artwork onto the standard 80.5% Apple Icon Grid
	/// with transparent margins, matching macOS system apps (Safari, Music, Settings).
	static func padToAppleGrid(image: NSImage) -> NSImage {
		let canvasSize = NSSize(
			width: AppConstants.Icon.canvasDimension,
			height: AppConstants.Icon.canvasDimension
		)
		let contentSize = NSSize(
			width: AppConstants.Icon.squircleDimension,
			height: AppConstants.Icon.squircleDimension
		)
		let origin = NSPoint(
			x: (canvasSize.width - contentSize.width) / 2.0,
			y: (canvasSize.height - contentSize.height) / 2.0
		)
		let drawRect = NSRect(origin: origin, size: contentSize)

		let padded = NSImage(size: canvasSize)
		padded.lockFocus()
		NSGraphicsContext.current?.imageInterpolation = .high
		image.draw(in: drawRect, from: .zero, operation: .copy, fraction: 1.0)
		padded.unlockFocus()
		return padded
	}

	/// Generates a dynamically tinted version of the bundled app icon by shifting the cyan signal layer
	/// to match the target hue in YIQ color space, preserving all Liquid Glass reflections and Apple grid padding.
	static func tintedDefaultIcon(for targetHue: Double) -> NSImage? {
		guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
			let baseIcon = NSImage(contentsOf: iconURL),
			let tiffData = baseIcon.tiffRepresentation,
			let ciImage = CIImage(data: tiffData)
		else { return nil }

		let (targetR, targetG, targetB) = rgb(
			hue: targetHue,
			saturation: 1.0,
			brightness: 1.0
		)
		let baseAngle = yiqChromaAngle(red: 0.094, green: 0.82, blue: 1.0)
		let targetAngle = yiqChromaAngle(red: targetR, green: targetG, blue: targetB)
		var deltaAngle = targetAngle - baseAngle
		while deltaAngle > Double.pi { deltaAngle -= 2 * Double.pi }
		while deltaAngle < -Double.pi { deltaAngle += 2 * Double.pi }

		let filter = CIFilter(name: "CIHueAdjust")
		filter?.setValue(ciImage, forKey: kCIInputImageKey)
		filter?.setValue(deltaAngle, forKey: kCIInputAngleKey)

		guard let outputCI = filter?.outputImage else { return nil }
		let context = CIContext(options: [.useSoftwareRenderer: false])
		guard let cgImage = context.createCGImage(outputCI, from: outputCI.extent) else {
			return nil
		}

		let rawTintedImage = NSImage(
			cgImage: cgImage,
			size: NSSize(width: outputCI.extent.width, height: outputCI.extent.height)
		)
		return padToAppleGrid(image: rawTintedImage)
	}

	private static func yiqChromaAngle(red: Double, green: Double, blue: Double) -> Double {
		let i = 0.596 * red - 0.274 * green - 0.322 * blue
		let q = 0.211 * red - 0.523 * green + 0.312 * blue
		return atan2(q, i)
	}

	private static func rgb(
		hue: Double,
		saturation: Double,
		brightness: Double
	) -> (Double, Double, Double) {
		let c = brightness * saturation
		let x = c * (1 - abs((hue * 6).truncatingRemainder(dividingBy: 2) - 1))
		let m = brightness - c
		let (r1, g1, b1): (Double, Double, Double)
		switch hue * 6 {
		case 0..<1: (r1, g1, b1) = (c, x, 0)
		case 1..<2: (r1, g1, b1) = (x, c, 0)
		case 2..<3: (r1, g1, b1) = (0, c, x)
		case 3..<4: (r1, g1, b1) = (0, x, c)
		case 4..<5: (r1, g1, b1) = (x, 0, c)
		default: (r1, g1, b1) = (c, 0, x)
		}
		return (r1 + m, g1 + m, b1 + m)
	}
}
