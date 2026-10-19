// SPDX-License-Identifier: MPL-2.0

import AppKit

// Draws into an 8-bit device-RGBA bitmap at a fixed pixel size, so output never depends on a
// screen and the work can run off the main actor (unlike `lockFocus`).
enum RGBABitmap {
	static func render(
		pixelsWide: Int,
		pixelsHigh: Int,
		size: NSSize,
		draw: (NSGraphicsContext) -> Void
	) -> NSBitmapImageRep? {
		guard
			let bitmap = NSBitmapImageRep(
				bitmapDataPlanes: nil,
				pixelsWide: pixelsWide,
				pixelsHigh: pixelsHigh,
				bitsPerSample: 8,
				samplesPerPixel: 4,
				hasAlpha: true,
				isPlanar: false,
				colorSpaceName: .deviceRGB,
				bytesPerRow: 0,
				bitsPerPixel: 0
			)
		else { return nil }
		// The context derives its point-to-pixel transform from the size set beforehand.
		bitmap.size = size
		guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
		NSGraphicsContext.saveGraphicsState()
		defer { NSGraphicsContext.restoreGraphicsState() }
		NSGraphicsContext.current = context
		draw(context)
		return bitmap
	}

	static func image(
		size: NSSize,
		scale: CGFloat,
		draw: (NSGraphicsContext) -> Void
	) -> NSImage? {
		guard
			let bitmap = render(
				pixelsWide: Int(size.width * scale),
				pixelsHigh: Int(size.height * scale),
				size: size,
				draw: draw
			)
		else { return nil }
		let image = NSImage(size: size)
		image.addRepresentation(bitmap)
		return image
	}
}
