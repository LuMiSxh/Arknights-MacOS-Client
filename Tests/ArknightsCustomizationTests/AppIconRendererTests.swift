// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import Testing

@testable import ArknightsCustomization

@MainActor
@Test
func operatorIconTreatmentsRenderOnTheNormalizedCanvas() throws {
	let source = wideSource()
	let sourceData = try #require(source.tiffRepresentation)

	for treatment in [OperatorIconTreatment.launcher, .game] {
		let icon = try #require(
			AppIconRenderer.createPresetIcon(
				from: sourceData,
				treatment: treatment,
				accentHue: 0.72
			)
		)
		#expect(
			icon.size
				== NSSize(
					width: AppConstants.Icon.canvasDimension,
					height: AppConstants.Icon.canvasDimension
				)
		)
	}

	let padded = AppIconRenderer.padToAppleGrid(image: source)
	let paddedData = try #require(padded.tiffRepresentation)
	let bitmap = try #require(NSBitmapImageRep(data: paddedData))
	let scale = Double(bitmap.pixelsWide) / AppConstants.Icon.canvasDimension
	let box = AppConstants.Icon.squircleDimension * scale
	let center = bitmap.pixelsWide / 2

	func isOpaque(x: Int, y: Int) -> Bool {
		(bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5
	}
	// A wide image fills the box horizontally and half of it vertically.
	#expect(isOpaque(x: center - Int(box / 2) + 4, y: center))
	#expect(isOpaque(x: center, y: center + Int(box / 4) - 4))
	#expect(!isOpaque(x: center, y: center + Int(box / 4) + 4))
	#expect(!isOpaque(x: center, y: center - Int(box / 4) - 4))
}

@MainActor
private func wideSource() -> NSImage {
	let source = NSImage(size: NSSize(width: 200, height: 100))
	source.lockFocus()
	NSColor.red.setFill()
	NSBezierPath(rect: NSRect(x: 0, y: 0, width: 200, height: 100)).fill()
	source.unlockFocus()
	return source
}
