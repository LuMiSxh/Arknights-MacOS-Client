// SPDX-License-Identifier: MPL-2.0

import AppKit

/// Owns an immutable image snapshot because MediaPlayer invokes its synchronous artwork
/// callback on a private queue rather than the main actor.
final class NowPlayingArtworkProvider: @unchecked Sendable {
	private let image: NSImage

	init(image: NSImage) {
		self.image = image.copy() as? NSImage ?? image
	}

	func image(for requestedSize: NSSize) -> NSImage {
		let copy = image.copy() as? NSImage ?? image
		if requestedSize.width > 0, requestedSize.height > 0 {
			copy.size = requestedSize
		}
		return copy
	}
}
