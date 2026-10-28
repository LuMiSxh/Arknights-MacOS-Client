// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsAudio

@MainActor
struct BackgroundMusicTrackChangeTests {
	@Test
	func nextAsksYouTubeForTheNextTrackAndCompletesOnAPlayingPlayerThatReadsADifferentVideo()
		async throws
	{
		let fixture = try MusicFixture(clock: HeldClock())
		defer { fixture.remove() }
		let controller = fixture.controller
		controller.currentSource = .playlist(id: "list")
		fixture.fake.metadata = try FakeMusicPlayer.metadata(videoID: "a", title: "First")

		controller.playNextTrack()
		#expect(await waitForCondition { fixture.fake.count("nextVideo") == 1 })
		for _ in 0..<20 { await Task.yield() }
		// The player still reads the old video, so a bare state change does not end the wait.
		fixture.fake.emit(.playback(.playing))
		for _ in 0..<20 { await Task.yield() }
		#expect(controller.isChangingTrack)

		// No `.metadata` event arrives; the read of the player alone proves the change.
		fixture.fake.metadata = try FakeMusicPlayer.metadata(videoID: "b", title: "Second")
		fixture.fake.emit(.playback(.buffering))
		fixture.fake.emit(.playback(.playing))
		#expect(await waitForCondition { !controller.isChangingTrack })
		#expect(controller.currentMusicTitle == "Second")
		#expect(fixture.fake.count("playVideoInPlaylist") == 0)
	}

	@Test
	func aTrackChangeThatTimesOutEndsAndShowsWhatThePlayerReads() async throws {
		let clock = HeldClock()
		let fixture = try MusicFixture(clock: clock)
		defer { fixture.remove() }
		let controller = fixture.controller
		controller.currentSource = .playlist(id: "list")
		controller.currentMusicTitle = "Stale"
		fixture.fake.metadata = try FakeMusicPlayer.metadata(videoID: "a", title: "First")

		controller.playPreviousTrack()
		#expect(await waitForCondition { fixture.fake.count("previousVideo") == 1 })
		for _ in 0..<20 { await Task.yield() }
		#expect(controller.isChangingTrack)

		fixture.fake.metadata = try FakeMusicPlayer.metadata(videoID: "b", title: "Second")
		clock.release()
		#expect(await waitForCondition { !controller.isChangingTrack })
		#expect(controller.currentMusicTitle == "Second")
	}

	@Test
	func aFailedTrackCommandEndsTheEventSubscription() async throws {
		let fixture = try MusicFixture()
		defer { fixture.remove() }
		let controller = fixture.controller
		controller.currentSource = .playlist(id: "list")
		fixture.fake.failsNavigation = true

		controller.playNextTrack()

		#expect(await waitForCondition { fixture.fake.terminatedStreams == 1 })
		#expect(await waitForCondition { !controller.isChangingTrack })
	}
}
