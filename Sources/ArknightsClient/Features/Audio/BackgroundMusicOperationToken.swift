// SPDX-License-Identifier: MPL-2.0

import Foundation
import YouTubePlayerKit

struct BackgroundMusicOperationToken {
	let id = UUID()
	let generation: UUID
	let player: YouTubePlayer
}
