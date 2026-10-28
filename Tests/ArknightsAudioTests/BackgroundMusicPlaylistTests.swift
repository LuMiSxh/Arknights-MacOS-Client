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

	@Test
	func setupForTheSameSourceKeepsTheStartedPlaylistButANewSourceRestartsIt() async throws {
		let fixture = try MusicFixture(randomIndex: { $0 - 1 })
		defer { fixture.remove() }
		let controller = fixture.controller
		controller.settings.playsLauncherMusic = true
		controller.settings.launcherMusicURL = "https://www.youtube.com/playlist?list=one"
		fixture.fake.playlist = ["a", "b", "c", "d"]
		controller.enabledDidChange(to: true)
		fixture.fake.emit(.playback(.cued))
		#expect(await waitForCondition { fixture.fake.playedIndices == [3] })

		controller.enabledDidChange(to: true)
		fixture.fake.emit(.playback(.cued))
		#expect(await waitForCondition { fixture.fake.count("play") == 1 })
		#expect(fixture.fake.playedIndices == [3])

		controller.settings.launcherMusicURL = "https://www.youtube.com/playlist?list=two"
		controller.enabledDidChange(to: true)
		fixture.fake.emit(.playback(.cued))
		#expect(await waitForCondition { fixture.fake.playedIndices == [3, 3] })
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
			#expect(await waitForCondition { fixture.fake.count("nextVideo") == skipped })
		}
		if playsBetween {
			fixture.fake.emit(.playback(.playing))
			#expect(await waitForCondition { controller.playbackState == .playing })
		}
		fixture.fake.emit(.failure(.unplayableTrack))

		if playsBetween {
			#expect(await waitForCondition { fixture.fake.count("nextVideo") == bound })
			#expect(!controller.isUnavailable)
			#expect(fixture.fake.count("pause") == 0)
		} else {
			#expect(await waitForCondition { controller.isUnavailable })
			#expect(await waitForCondition { fixture.fake.count("pause") == 1 })
			#expect(fixture.fake.count("nextVideo") == bound - 1)
		}
	}
}
