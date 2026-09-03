// SPDX-License-Identifier: MPL-2.0

import AppKit
import CoreGraphics
import Foundation
import ImageIO

/// Stores encoded immutable artwork and creates a fresh AppKit image per callback.
final class NowPlayingArtworkProvider: Sendable {
	private let encodedImageData: Data
	private let defaultSize: CGSize

	init(image: NSImage) {
		encodedImageData = image.tiffRepresentation ?? Self.placeholderData
		defaultSize = image.size
	}

	func image(for requestedSize: NSSize) -> NSImage {
		let size =
			requestedSize.width > 0 && requestedSize.height > 0
			? requestedSize
			: defaultSize
		let cgImage =
			Self.cgImage(from: encodedImageData) ?? Self.cgImage(from: Self.placeholderData)!
		return NSImage(cgImage: cgImage, size: size)
	}

	private static func cgImage(from data: Data) -> CGImage? {
		guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
		return CGImageSourceCreateImageAtIndex(source, 0, nil)
	}

	private static let placeholderData = Data(
		base64Encoded:
			"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zl1sAAAAASUVORK5CYII="
	)!
}
