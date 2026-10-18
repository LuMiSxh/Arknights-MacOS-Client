// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import CoreImage
import SwiftUI

enum AppIconRenderer {
	// The transparent margin matches the 80.5% Apple icon grid used by macOS system apps
	// (Safari, Music, Settings).
	static func padToAppleGrid(image: NSImage) -> NSImage {
		let canvasSize = NSSize(
			width: AppConstants.Icon.canvasDimension,
			height: AppConstants.Icon.canvasDimension
		)
		let box = AppConstants.Icon.squircleDimension
		let scale = min(box / max(image.size.width, 1), box / max(image.size.height, 1))
		let contentSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
		let origin = NSPoint(
			x: (canvasSize.width - contentSize.width) / 2.0,
			y: (canvasSize.height - contentSize.height) / 2.0
		)
		let drawRect = NSRect(origin: origin, size: contentSize)

		return RGBABitmap.image(size: canvasSize, scale: AppConstants.Icon.renderScale) { context in
			context.imageInterpolation = .high
			image.draw(in: drawRect, from: .zero, operation: .copy, fraction: 1.0)
		} ?? image
	}

	static func tintedDefaultIcon(for targetHue: Double) -> NSImage? {
		guard let baseIcon = bundledImage(.appIconTintSource),
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

	// The 1024-pixel render produced by `just icon`; the compiled ICNS tops out at 256 pixels.
	static func bundledImage(_ resource: BundledResource) -> NSImage? {
		do {
			return NSImage(contentsOf: try resource.url())
		} catch {
			NSLog("ArknightsClient could not load \(resource.path): \(error)")
			return nil
		}
	}

	// `CIHueAdjust` rotates hue in `NSColor`'s HSB circle, not YIQ chroma-angle space.
	static func hueRotationAngle(to targetHue: Double) -> Double {
		var deltaAngle = (targetHue - AppConstants.Icon.baseCyanHue) * 2 * Double.pi
		while deltaAngle > Double.pi { deltaAngle -= 2 * Double.pi }
		while deltaAngle < -Double.pi { deltaAngle += 2 * Double.pi }
		return deltaAngle
	}
}
