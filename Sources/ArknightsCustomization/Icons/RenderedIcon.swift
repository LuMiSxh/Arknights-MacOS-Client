// SPDX-License-Identifier: MPL-2.0

import AppKit

// The image is never mutated after rendering, so sharing it across
// actors and caches is safe.
// `@unchecked`: NSImage is not Sendable, but this wrapper never mutates it after `init`.
final class RenderedIcon: @unchecked Sendable {
	let image: NSImage

	init(_ image: NSImage) {
		self.image = image
	}
}

// `@unchecked`: NSImage is not Sendable, but this wrapper never mutates either image after `init`.
final class RenderedIconPair: @unchecked Sendable {
	let launcher: NSImage
	let game: NSImage

	init(launcher: NSImage, game: NSImage) {
		self.launcher = launcher
		self.game = game
	}
}
