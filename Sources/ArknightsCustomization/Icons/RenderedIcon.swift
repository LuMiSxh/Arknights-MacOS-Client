// SPDX-License-Identifier: MPL-2.0

import AppKit

// The image is never mutated after rendering, so sharing it across
// actors and caches is safe.
final class RenderedIcon: @unchecked Sendable {
	let image: NSImage

	init(_ image: NSImage) {
		self.image = image
	}
}

final class RenderedIconPair: @unchecked Sendable {
	let launcher: NSImage
	let game: NSImage

	init(launcher: NSImage, game: NSImage) {
		self.launcher = launcher
		self.game = game
	}
}
