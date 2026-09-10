// SPDX-License-Identifier: MPL-2.0

import AppKit
import CoreImage
import Testing

@testable import ArknightsClient

@MainActor
@Test
func operatorIconTreatmentsRenderOnTheNormalizedCanvas() throws {
	let source = NSImage(size: NSSize(width: 64, height: 64))
	source.lockFocus()
	NSColor.systemOrange.setFill()
	NSBezierPath(rect: NSRect(x: 0, y: 0, width: 64, height: 64)).fill()
	source.unlockFocus()
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
}

@MainActor
@Test
func launcherTreatmentUsesTheDynamicThemeHue() throws {
	let sourceData = try whiteCircleSourceData()
	let cyan = try #require(
		AppIconRenderer.createPresetIcon(
			from: sourceData, treatment: .launcher, accentHue: nil)
	)
	let purple = try #require(
		AppIconRenderer.createPresetIcon(
			from: sourceData, treatment: .launcher, accentHue: 0.78)
	)

	#expect(cyan.tiffRepresentation != purple.tiffRepresentation)
}

@MainActor
@Test
func gameTreatmentIgnoresTheDynamicThemeHue() throws {
	let sourceData = try whiteCircleSourceData()
	let cyan = try #require(
		AppIconRenderer.createPresetIcon(from: sourceData, treatment: .game, accentHue: nil)
	)
	let purple = try #require(
		AppIconRenderer.createPresetIcon(from: sourceData, treatment: .game, accentHue: 0.78)
	)

	#expect(cyan.tiffRepresentation == purple.tiffRepresentation)
}

@Test(arguments: [
	("red", 0.0), ("green", 0.33), ("blue", 0.66), ("magenta", 0.83), ("yellow", 0.16),
])
func hueRotationAngleProducesTheRequestedHue(name: String, targetHue: Double) throws {
	let base = AppConstants.Icon.baseCyanHue
	let swatch = CIImage(color: CIColor(red: 0.094, green: 0.82, blue: 1.0, alpha: 1))
		.cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
	let filter = try #require(CIFilter(name: "CIHueAdjust"))
	filter.setValue(swatch, forKey: kCIInputImageKey)
	filter.setValue(AppIconRenderer.hueRotationAngle(to: targetHue), forKey: kCIInputAngleKey)
	let output = try #require(filter.outputImage)
	let context = CIContext(options: [.useSoftwareRenderer: false])
	let cgImage = try #require(context.createCGImage(output, from: output.extent))
	let rep = NSBitmapImageRep(cgImage: cgImage)
	let pixel = try #require(rep.colorAt(x: 2, y: 2))

	var outputHue: CGFloat = 0
	pixel.getHue(&outputHue, saturation: nil, brightness: nil, alpha: nil)

	var delta = abs(Double(outputHue) - targetHue)
	delta = min(delta, 1 - delta)
	#expect(delta < 0.12, "base=\(base) target=\(targetHue) got \(outputHue)")
}

@MainActor
private func whiteCircleSourceData() throws -> Data {
	let source = NSImage(size: NSSize(width: 64, height: 64))
	source.lockFocus()
	NSColor.white.setFill()
	NSBezierPath(ovalIn: NSRect(x: 8, y: 8, width: 48, height: 48)).fill()
	source.unlockFocus()
	return try #require(source.tiffRepresentation)
}
