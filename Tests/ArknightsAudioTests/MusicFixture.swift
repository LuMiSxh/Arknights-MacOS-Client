// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsCustomization
import ArknightsTestSupport
import Foundation
import YouTubePlayerKit

@testable import ArknightsAudio

/// Records every player command and can hold `getPlaylist` until the test releases it.
@MainActor
final class FakeMusicPlayer {
	private(set) var commands: [String] = []
	private(set) var playedIndices: [Int] = []
	private(set) var isHoldingPlaylist = false
	var holdsPlaylist = false
	var holdsMetadata = false
	private(set) var isHoldingMetadata = false
	private var metadataGate: CheckedContinuation<Void, Never>?
	var playlist = ["a", "b"]
	/// Makes `nextVideo` and `previousVideo` throw.
	var failsNavigation = false
	private(set) var terminatedStreams = 0
	/// What `getPlaybackMetadata` returns; it throws while nil.
	var metadata: YouTubePlayer.PlaybackMetadata?
	private var gate: CheckedContinuation<Void, Never>?
	private var eventStreams: [AsyncStream<BackgroundMusicPlayerEvent>.Continuation] = []

	/// Delivers `event` to every subscription, as the player would.
	func emit(_ event: BackgroundMusicPlayerEvent) {
		for stream in eventStreams { stream.yield(event) }
	}

	static func metadata(
		videoID: String,
		title: String? = nil
	) throws -> YouTubePlayer.PlaybackMetadata {
		let titleField = title.map { #","title":"\#($0)""# } ?? ""
		return try JSONDecoder().decode(
			YouTubePlayer.PlaybackMetadata.self,
			from: Data(#"{"videoId":"\#(videoID)"\#(titleField)}"#.utf8)
		)
	}

	struct Unsupported: Error {}

	func releasePlaylist() {
		gate?.resume()
		gate = nil
		isHoldingPlaylist = false
	}

	func releaseMetadata() {
		metadataGate?.resume()
		metadataGate = nil
		isHoldingMetadata = false
	}

	func count(_ command: String) -> Int {
		commands.filter { $0 == command }.count
	}

	var playerCommands: BackgroundMusicPlayerCommands {
		BackgroundMusicPlayerCommands(
			events: { [self] _ in
				let (stream, continuation) = AsyncStream.makeStream(
					of: BackgroundMusicPlayerEvent.self,
					bufferingPolicy: .bufferingNewest(AppConstants.Music.playerEventBufferLimit)
				)
				eventStreams.append(continuation)
				continuation.onTermination = { _ in
					Task { @MainActor in self.terminatedStreams += 1 }
				}
				return stream
			},
			load: { [self] _, _ in commands.append("load") },
			getPlaylist: { [self] _ in
				commands.append("getPlaylist")
				if holdsPlaylist {
					isHoldingPlaylist = true
					await withCheckedContinuation { gate = $0 }
				}
				return playlist
			},
			getPlaybackMetadata: { [self] _ in
				commands.append("getPlaybackMetadata")
				if holdsMetadata {
					isHoldingMetadata = true
					await withCheckedContinuation { metadataGate = $0 }
				}
				guard let metadata else { throw Unsupported() }
				return metadata
			},
			playVideoInPlaylist: { [self] _, index in
				commands.append("playVideoInPlaylist")
				playedIndices.append(index)
			},
			nextVideo: { [self] _ in
				commands.append("nextVideo")
				if failsNavigation { throw Unsupported() }
			},
			previousVideo: { [self] _ in
				commands.append("previousVideo")
				if failsNavigation { throw Unsupported() }
			},
			setLoop: { [self] _, _ in commands.append("setLoop") },
			setShuffle: { [self] _, _ in commands.append("setShuffle") },
			play: { [self] _ in commands.append("play") },
			pause: { [self] _ in commands.append("pause") },
			setVolume: { [self] _, _ in commands.append("setVolume") }
		)
	}
}

/// A controller wired to a fake player and a clock that never really sleeps.
@MainActor
struct MusicFixture {
	let fake = FakeMusicPlayer()
	let clock: any Clock<Duration>
	let controller: BackgroundMusicController
	private let temporary: TemporaryDirectory
	private let defaults: UserDefaults
	private let suiteName: String

	init(
		clock: any Clock<Duration> = RecordingClock(),
		randomIndex: @escaping (Int) -> Int = { _ in 0 }
	) throws {
		self.clock = clock
		temporary = try TemporaryDirectory("BackgroundMusicControllerTests")
		(defaults, suiteName) = makeIsolatedDefaults("BackgroundMusicControllerTests")
		let paths = AppPaths(
			applicationSupportDirectory: temporary.url.appending(path: "Support"),
			cachesDirectory: temporary.url.appending(path: "Caches"),
			libraryDirectory: temporary.url.appending(path: "Library")
		)
		controller = BackgroundMusicController(
			lifecycle: LauncherLifecycleStore(log: LauncherLog(fileURL: paths.launcherLogFile)),
			settings: LauncherPreferencesController(
				store: LauncherPreferencesStore(defaults: defaults)
			),
			launcherIconManager: LauncherIconManager(
				setBundleIcon: { _ in true },
				setRunningIcon: { _ in },
				defaultIcon: { NSImage(size: NSSize(width: 64, height: 64)) }
			),
			playerCommands: fake.playerCommands,
			clock: clock,
			randomIndex: randomIndex,
			openURL: { _ in }
		)
		controller.player = YouTubePlayer(source: .video(id: "test"))
		controller.phase = .playing
	}

	func remove() {
		temporary.remove()
		defaults.removePersistentDomain(forName: suiteName)
	}
}

extension LauncherActivity {
	static func testRunningGame() -> LauncherActivity {
		.runningGame(sessionID: UUID(), processIdentifier: 1)
	}
}
