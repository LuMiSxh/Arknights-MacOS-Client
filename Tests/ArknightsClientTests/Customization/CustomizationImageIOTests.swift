// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import Testing

@testable import ArknightsClient

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
		#expect(CustomizationImageIO.dimensionsAreSafe(width: 6_000, height: 6_000))
		#expect(!CustomizationImageIO.dimensionsAreSafe(width: 6_001, height: 6_001))
		#expect(
			!CustomizationImageIO.dimensionsAreSafe(
				width: AppConstants.Artwork.maximumDimension + 1, height: 1))
		#expect(!CustomizationImageIO.dimensionsAreSafe(width: Int.max, height: Int.max))
		let image = NSImage(size: NSSize(width: 16, height: 16))
		image.lockFocus()
		NSColor.systemPurple.setFill()
		NSBezierPath(rect: NSRect(x: 0, y: 0, width: 16, height: 16)).fill()
		image.unlockFocus()
		let data = try #require(image.tiffRepresentation)
		try CustomizationImageIO.validate(data, source: URL(filePath: "/tmp/valid.tiff"))
	}
}
