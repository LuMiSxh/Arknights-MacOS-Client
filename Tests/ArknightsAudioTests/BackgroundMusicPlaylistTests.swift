// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsAudio

@MainActor
struct BackgroundMusicPlaylistTests {
	@Test
	func playlistStartsOnTheRandomTrackWithoutPlayingTheFirstOne() async throws {
		let fixture = try MusicFixture(randomIndex: { $0 - 1 })
		defer { fixture.remove() }
		let controller = fixture.controller
		controller.settings.playsLauncherMusic = true
		controller.currentSource = .playlist(id: "list")
		fixture.fake.playlist = ["a", "b", "c", "d"]
		controller.observeEvents(of: try #require(controller.player))

		fixture.fake.emit(.playback(.cued))
		#expect(
			await waitForCondition {
				controller.fadeTask == nil && fixture.fake.count("setVolume") > 1
			})

		let commands = fixture.fake.commands
		#expect(
			commands.filter { $0 != "setVolume" } == [
				"setLoop", "setShuffle", "getPlaylist", "playVideoInPlaylist",
			])
		#expect(fixture.fake.playedIndices == [3])
		#expect(commands.last == "setVolume")
	}

	@Test(arguments: [false, true])
	func playerFailuresSkipTracksUntilTheBoundUnlessAPlayingTrackResetsIt(
		playsBetween: Bool
	) async throws {
		let fixture = try MusicFixture()
		defer { fixture.remove() }
		let controller = fixture.controller
		controller.currentSource = .playlist(id: "list")
		controller.observeEvents(of: try #require(controller.player))
		let bound = AppConstants.Music.maxConsecutivePlayerFailures

		for skipped in 1..<bound {
			fixture.fake.emit(.failure(.unplayableTrack))
			#expect(await waitForCondition { fixture.fake.count("playVideoInPlaylist") == skipped })
		}
		if playsBetween {
			fixture.fake.emit(.playback(.playing))
			#expect(await waitForCondition { controller.playbackState == .playing })
		}
		fixture.fake.emit(.failure(.unplayableTrack))

		if playsBetween {
			#expect(await waitForCondition { fixture.fake.count("playVideoInPlaylist") == bound })
			#expect(!controller.isUnavailable)
			#expect(fixture.fake.count("pause") == 0)
		} else {
			#expect(await waitForCondition { controller.isUnavailable })
			#expect(await waitForCondition { fixture.fake.count("pause") == 1 })
			#expect(fixture.fake.count("playVideoInPlaylist") == bound - 1)
		}
	}

	@Test
	func trackChangeCompletesWhenTheNewTrackPlaysAndGivesUpAfterTheTimeout() async throws {
		let clock = HeldClock()
		let fixture = try MusicFixture(clock: clock)
		defer { fixture.remove() }
		let controller = fixture.controller
		controller.currentSource = .playlist(id: "list")

		controller.playNextTrack()
		#expect(await waitForCondition { fixture.fake.count("playVideoInPlaylist") == 1 })
		for _ in 0..<20 { await Task.yield() }
		// The previous track's video and a bare state change do not end the wait.
		fixture.fake.emit(.metadata(try FakeMusicPlayer.metadata(videoID: "a")))
		fixture.fake.emit(.playback(.playing))
		for _ in 0..<20 { await Task.yield() }
		#expect(controller.isChangingTrack)

		fixture.fake.emit(.metadata(try FakeMusicPlayer.metadata(videoID: "b")))
		#expect(await waitForCondition { !controller.isChangingTrack })

		controller.playNextTrack()
		#expect(await waitForCondition { fixture.fake.count("playVideoInPlaylist") == 2 })
		for _ in 0..<20 { await Task.yield() }
		#expect(controller.isChangingTrack)
		clock.release()
		#expect(await waitForCondition { !controller.isChangingTrack })
	}
}
