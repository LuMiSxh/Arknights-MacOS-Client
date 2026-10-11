// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation
import YouTubePlayerKit

@MainActor
struct BackgroundMusicPlayerCommands {
	typealias PlayerCommand = @MainActor (YouTubePlayer) async throws -> Void
	typealias VolumeCommand = @MainActor (YouTubePlayer, Int) async throws -> Void

	let play: PlayerCommand
	let pause: PlayerCommand
	let setVolume: VolumeCommand

	static let live = Self(
		play: { try await $0.play() },
		pause: { try await $0.pause() },
		setVolume: { player, volume in
			try await player.evaluate(
				javaScript: .youTubePlayer(
					functionName: "setVolume",
					parameters: [volume]
				)
			)
		}
	)
}

/// The value types the background-music controller passes between its track, playback, and
/// fade paths.

package enum PlaybackIntent {
	case playing
	case paused
}

enum BackgroundMusicOperationKind {
	case trackChange
	case playbackChange(PlaybackIntent)
}

struct BackgroundMusicPlaybackExpectation {
	let token: TaskSlot.Token
	let intent: PlaybackIntent
}

package enum BackgroundMusicOperation {
	case idle
	case trackChange(TaskSlot.Token)
	case playbackChange(TaskSlot.Token, PlaybackIntent)

	var isChangingTrack: Bool {
		if case .trackChange = self { return true }
		return false
	}

	var isChangingPlayback: Bool {
		if case .playbackChange = self { return true }
		return false
	}

	package var token: TaskSlot.Token? {
		switch self {
		case .idle:
			nil
		case .trackChange(let token), .playbackChange(let token, _):
			token
		}
	}
}
