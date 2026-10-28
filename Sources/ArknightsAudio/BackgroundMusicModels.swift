// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
@preconcurrency import Combine
import Foundation
import YouTubePlayerKit

@MainActor
struct BackgroundMusicPlayerCommands {
	typealias PlayerCommand = @MainActor (YouTubePlayer) async throws -> Void
	typealias VolumeCommand = @MainActor (YouTubePlayer, Int) async throws -> Void
	typealias SourceCommand = @MainActor (YouTubePlayer, YouTubePlayer.Source) async throws -> Void
	typealias IndexCommand = @MainActor (YouTubePlayer, Int) async throws -> Void
	typealias FlagCommand = @MainActor (YouTubePlayer, Bool) async throws -> Void

	/// A subscription to one player's changes. Each call starts an independent stream that ends
	/// when its consumer stops iterating.
	let events: @MainActor (YouTubePlayer) -> AsyncStream<BackgroundMusicPlayerEvent>
	let load: SourceCommand
	let getPlaylist: @MainActor (YouTubePlayer) async throws -> [String]?
	let getPlaylistIndex: @MainActor (YouTubePlayer) async throws -> Int
	let getPlaybackMetadata:
		@MainActor (YouTubePlayer) async throws -> YouTubePlayer.PlaybackMetadata
	let playVideoInPlaylist: IndexCommand
	let setLoop: FlagCommand
	let setShuffle: FlagCommand
	let play: PlayerCommand
	let pause: PlayerCommand
	let setVolume: VolumeCommand

	static let live = Self(
		events: { liveEvents(of: $0) },
		// A cued playlist waits for the launcher to pick its first track; loading would play track 0.
		load: { player, source in
			if case .playlist = source {
				try await player.cue(source: source)
			} else {
				try await player.load(source: source)
			}
		},
		getPlaylist: { try await $0.getPlaylist() },
		getPlaylistIndex: { try await $0.getPlaylistIndex() },
		getPlaybackMetadata: { try await $0.getPlaybackMetadata() },
		playVideoInPlaylist: { try await $0.playVideoInPlaylist(at: $1) },
		setLoop: { try await $0.setLoopPlaylist(enabled: $1) },
		setShuffle: { try await $0.setShufflePlaylist(enabled: $1) },
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

	private static func liveEvents(
		of player: YouTubePlayer
	) -> AsyncStream<BackgroundMusicPlayerEvent> {
		AsyncStream(bufferingPolicy: .bufferingNewest(AppConstants.Music.playerEventBufferLimit)) {
			continuation in
			// The player replays its current playback state to a new subscriber; only changes are events.
			let replaysPlaybackState = player.playbackState != nil
			let playback = player.playbackStatePublisher
				.dropFirst(replaysPlaybackState ? 1 : 0)
				.removeDuplicates()
				.map(BackgroundMusicPlayerEvent.playback)
				.eraseToAnyPublisher()
			let metadata = player.playbackMetadataPublisher
				.map(BackgroundMusicPlayerEvent.metadata)
				.eraseToAnyPublisher()
			// The iframe reports a video failure as an event; the state publisher drops repeats of it.
			let playerEvents = player.eventPublisher
				.compactMap { event -> BackgroundMusicPlayerEvent? in
					switch event.name {
					case .error: .failure(.unplayableTrack)
					case .connectionIssue, .iFrameApiFailedToLoad: .failure(.unreachable)
					default: nil
					}
				}
				.eraseToAnyPublisher()
			let webViewFailures = player.statePublisher
				.compactMap { state -> BackgroundMusicPlayerEvent? in
					switch state.error {
					case .setupFailed, .didFailProvisionalNavigation, .didFailNavigation,
						.webContentProcessDidTerminate:
						.failure(.unreachable)
					default: nil
					}
				}
				.eraseToAnyPublisher()
			let subscription = Publishers.MergeMany([
				playback, metadata, playerEvents, webViewFailures,
			])
			.sink { continuation.yield($0) }
			continuation.onTermination = { _ in subscription.cancel() }
		}
	}
}

enum BackgroundMusicPlayerEvent: Sendable {
	case playback(YouTubePlayer.PlaybackState)
	case metadata(YouTubePlayer.PlaybackMetadata)
	case failure(BackgroundMusicFailure)
}

extension YouTubePlayer.Source {
	var isPlaylist: Bool {
		if case .playlist = self { return true }
		return false
	}
}

enum BackgroundMusicFailure: Sendable {
	/// YouTube refuses this video: it is removed, private, or not embeddable.
	case unplayableTrack
	/// The player cannot reach YouTube.
	case unreachable
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
