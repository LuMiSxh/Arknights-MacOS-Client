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

	/// Generates a dynamically tinted version of the bundled app icon for the given hue.
	static func tintedDefaultIcon(for targetHue: Double) -> NSImage? {
		guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
			let baseIcon = NSImage(contentsOf: iconURL),
			let tiffData = baseIcon.tiffRepresentation,
			let ciImage = CIImage(data: tiffData)
		else { return nil }

		let filter = CIFilter(name: "CIHueAdjust")
		filter?.setValue(ciImage, forKey: kCIInputImageKey)
		filter?.setValue(hueRotationAngle(to: targetHue), forKey: kCIInputAngleKey)

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

	/// `CIHueAdjust` rotates hue in `NSColor`'s HSB circle, not YIQ chroma-angle space.
	static func hueRotationAngle(to targetHue: Double) -> Double {
		var deltaAngle = (targetHue - AppConstants.Icon.baseCyanHue) * 2 * Double.pi
		while deltaAngle > Double.pi { deltaAngle -= 2 * Double.pi }
		while deltaAngle < -Double.pi { deltaAngle += 2 * Double.pi }
		return deltaAngle
	}
}
