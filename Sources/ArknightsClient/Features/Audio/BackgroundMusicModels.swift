// SPDX-License-Identifier: MPL-2.0

import Foundation
import YouTubePlayerKit

/// The value types the background-music controller passes between its track, playback, and
/// fade paths.

enum PlaybackIntent {
	case playing
	case paused
}

enum BackgroundMusicOperationKind {
	case trackChange
	case playbackChange(PlaybackIntent)
}

/// Identifies one in-flight track or playback change, so a result arriving after the player
/// was replaced can be recognized as stale and discarded.
struct BackgroundMusicOperationToken {
	let id = UUID()
	let generation: UUID
	let player: YouTubePlayer
}

/// The fade path's own token; separate from `BackgroundMusicOperationToken` because a fade
/// and the operation that triggered it are cancelled independently.
struct BackgroundMusicFadeOperation {
	let id = UUID()
	let generation: UUID
	let player: YouTubePlayer
}

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

enum BackgroundMusicOperation {
	case idle
	case trackChange(BackgroundMusicOperationToken)
	case playbackChange(BackgroundMusicOperationToken, PlaybackIntent)

	var isChangingTrack: Bool {
		if case .trackChange = self { return true }
		return false
	}

	var isChangingPlayback: Bool {
		if case .playbackChange = self { return true }
		return false
	}

	var token: BackgroundMusicOperationToken? {
		switch self {
		case .idle:
			nil
		case .trackChange(let token), .playbackChange(let token, _):
			token
		}
	}
}
