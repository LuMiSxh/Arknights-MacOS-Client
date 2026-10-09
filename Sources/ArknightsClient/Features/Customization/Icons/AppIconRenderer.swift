// SPDX-License-Identifier: MPL-2.0

import AppKit
import CoreImage
import SwiftUI

/// Unified engine for generating, dynamically tinting, and grid-normalizing macOS application icons.
enum AppIconRenderer {
	/// Aspect-fits and centers full-bleed icon artwork onto the standard 80.5% Apple Icon Grid
	/// with transparent margins, matching macOS system apps (Safari, Music, Settings).
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

		// `lockFocus` renders at the scale of whichever screen AppKit picks, which differs on
		// mixed-scale multi-display setups; draw into a fixed-density bitmap instead.
		let pixels = Int(AppConstants.Icon.canvasDimension * AppConstants.Icon.renderScale)
		guard
			let bitmap = NSBitmapImageRep(
				bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
				bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
				colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
			)
		else { return image }
		// The context derives its point-to-pixel transform from the size set beforehand.
		bitmap.size = canvasSize
		guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return image }
		NSGraphicsContext.saveGraphicsState()
		NSGraphicsContext.current = context
		context.imageInterpolation = .high
		image.draw(in: drawRect, from: .zero, operation: .copy, fraction: 1.0)
		NSGraphicsContext.restoreGraphicsState()
		let padded = NSImage(size: canvasSize)
		padded.addRepresentation(bitmap)
		return padded
	}

	/// Generates a dynamically tinted version of the bundled app icon for the given hue.
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

	/// The 1024-pixel render produced by `just icon`; the compiled ICNS tops out at 256 pixels.
	static func bundledImage(_ resource: BundledResource) -> NSImage? {
		do {
			return NSImage(contentsOf: try resource.url())
		} catch {
			NSLog("ArknightsClient could not load \(resource.path): \(error)")
			return nil
		}
	}

	/// `CIHueAdjust` rotates hue in `NSColor`'s HSB circle, not YIQ chroma-angle space.
	static func hueRotationAngle(to targetHue: Double) -> Double {
		var deltaAngle = (targetHue - AppConstants.Icon.baseCyanHue) * 2 * Double.pi
		while deltaAngle > Double.pi { deltaAngle -= 2 * Double.pi }
		while deltaAngle < -Double.pi { deltaAngle += 2 * Double.pi }
		return deltaAngle
	}
}
