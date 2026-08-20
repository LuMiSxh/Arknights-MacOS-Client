// SPDX-License-Identifier: MPL-2.0

import AppKit
import Testing

@testable import ArknightsClient

@MainActor
@Test
func avatarIconStylesRenderOnTheNormalizedCanvas() throws {
	let source = NSImage(size: NSSize(width: 64, height: 64))
	source.lockFocus()
	NSColor.systemOrange.setFill()
	NSBezierPath(rect: NSRect(x: 0, y: 0, width: 64, height: 64)).fill()
	source.unlockFocus()
	let sourceData = try #require(source.tiffRepresentation)

	for style in AvatarIconStyle.allCases {
		let icon = try #require(
			AppIconRenderer.createAvatarIcon(
				from: sourceData,
				style: style,
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
func launcherGlassUsesTheDynamicThemeHue() throws {
	let source = NSImage(size: NSSize(width: 64, height: 64))
	source.lockFocus()
	NSColor.white.setFill()
	NSBezierPath(ovalIn: NSRect(x: 8, y: 8, width: 48, height: 48)).fill()
	source.unlockFocus()
	let sourceData = try #require(source.tiffRepresentation)
	let cyan = try #require(
		AppIconRenderer.createAvatarIcon(
			from: sourceData,
			style: .launcherGlass,
			accentHue: nil
		)?.tiffRepresentation
	)
	let purple = try #require(
		AppIconRenderer.createAvatarIcon(
			from: sourceData,
			style: .launcherGlass,
			accentHue: 0.78
		)?.tiffRepresentation
	)

	#expect(cyan != purple)
}
