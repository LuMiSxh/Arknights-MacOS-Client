// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import Foundation
import Testing

@testable import ArknightsCustomization

struct CustomizationImageIOTests {
	@Test
	func validatesArtworkBytesAndDimensions() throws {
		let source = URL(filePath: "/tmp/custom-artwork")
		#expect(throws: (any Error).self) {
			try CustomizationImageIO.validate(Data("not an image".utf8), source: source)
		}
		#expect(throws: (any Error).self) {
			try CustomizationImageIO.validate(
				Data(count: AppConstants.Artwork.launcherMaximumBytes + 1),
				source: source
			)
		}
		let image = NSImage(size: NSSize(width: 16, height: 16))
		image.lockFocus()
		NSColor.systemPurple.setFill()
		NSBezierPath(rect: NSRect(x: 0, y: 0, width: 16, height: 16)).fill()
		image.unlockFocus()
		let data = try #require(image.tiffRepresentation)
		try CustomizationImageIO.validate(data, source: URL(filePath: "/tmp/valid.tiff"))
	}

	@Test(arguments: [
		(13_280, 7_470, true),
		(AppConstants.Artwork.maximumDimension, 1, true),
		(AppConstants.Artwork.maximumDimension + 1, 1, false),
		(11_000, 11_000, false),
		(Int.max, Int.max, false),
	])
	func dimensionsAreCheckedAgainstTheArtworkLimits(width: Int, height: Int, isSafe: Bool) {
		#expect(CustomizationImageIO.dimensionsAreSafe(width: width, height: height) == isSafe)
	}
}
