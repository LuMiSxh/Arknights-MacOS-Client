// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation

/// The Home background: a still image, or a looping video with the poster frame it starts from.
package enum HeroBackground {
	case image(NSImage)
	case video(url: URL, poster: NSImage)

	/// The picture that stands for the background when it is not drawn live.
	var still: NSImage {
		switch self {
		case .image(let image), .video(_, let image):
			image
		}
	}
}
