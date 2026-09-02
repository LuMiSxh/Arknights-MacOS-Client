// SPDX-License-Identifier: MPL-2.0

import Foundation
import YouTubePlayerKit

struct BackgroundMusicPlaybackExpectation {
	let id: UUID
	let generation: UUID
	let player: YouTubePlayer
	let intent: PlaybackIntent

	init(
		generation: UUID,
		player: YouTubePlayer,
		intent: PlaybackIntent
	) {
		id = UUID()
		self.generation = generation
		self.player = player
		self.intent = intent
	}
}
