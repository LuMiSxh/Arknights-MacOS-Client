// SPDX-License-Identifier: MPL-2.0

import AppKit
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

@MainActor
private func whiteCircleSourceData() throws -> Data {
	let source = NSImage(size: NSSize(width: 64, height: 64))
	source.lockFocus()
	NSColor.white.setFill()
	NSBezierPath(ovalIn: NSRect(x: 8, y: 8, width: 48, height: 48)).fill()
	source.unlockFocus()
	return try #require(source.tiffRepresentation)
}
