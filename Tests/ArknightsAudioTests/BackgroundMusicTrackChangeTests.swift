// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
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
	func nextCompletesFromAPlayerReadWhenYouTubeNeverReportsPlaying() async throws {
		let fixture = try MusicFixture(clock: HeldClock())
		defer { fixture.remove() }
		let controller = fixture.controller
		controller.currentSource = .playlist(id: "list")
		fixture.fake.metadata = try FakeMusicPlayer.metadata(videoID: "a", title: "First")

		controller.playNextTrack()
		#expect(await waitForCondition { fixture.fake.count("nextVideo") == 1 })
		for _ in 0..<20 { await Task.yield() }

		fixture.fake.metadata = try FakeMusicPlayer.metadata(videoID: "b", title: "Second")
		fixture.fake.state = .playing
		fixture.fake.emit(.playback(.buffering))
		fixture.fake.emit(.metadata(try FakeMusicPlayer.metadata(videoID: "b", title: "Second")))

		#expect(await waitForCondition { !controller.isChangingTrack })
		#expect(controller.currentMusicTitle == "Second")
		#expect(controller.playbackState == .playing)
	}

	@Test
	func nextCompletesOnTheRecheckWhenOnlyBufferingIsEverReported() async throws {
		let clock = HeldClock()
		let fixture = try MusicFixture(clock: clock)
		defer { fixture.remove() }
		let controller = fixture.controller
		controller.currentSource = .playlist(id: "list")
		controller.currentMusicTitle = "Old"
		fixture.fake.metadata = try FakeMusicPlayer.metadata(videoID: "a", title: "Old")

		controller.playNextTrack()
		#expect(await waitForCondition { fixture.fake.count("nextVideo") == 1 })
		for _ in 0..<20 { await Task.yield() }
		fixture.fake.emit(.playback(.buffering))
		for _ in 0..<20 { await Task.yield() }
		#expect(controller.isChangingTrack)

		// No further event arrives; only the recheck can notice the new track.
		fixture.fake.metadata = try FakeMusicPlayer.metadata(videoID: "b", title: "New")
		fixture.fake.state = .playing
		// One recheck interval is far short of the timeout, so only the recheck can finish this.
		clock.advance(by: AppConstants.Music.trackStartRecheckInterval)

		#expect(await waitForCondition { !controller.isChangingTrack })
		#expect(controller.currentMusicTitle == "New")
		#expect(controller.playbackState == .playing)
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

	@Test
	func anEventStreamThatIsNeverIteratedEndsItsSubscriptionWhenItIsDropped() throws {
		let fixture = try MusicFixture()
		defer { fixture.remove() }
		let player = try #require(fixture.controller.player)

		var events: BackgroundMusicPlayerEvents? = fixture.fake.playerCommands.events(player)
		#expect(events != nil)
		#expect(fixture.fake.activeSubscriptions == 1)
		events = nil

		#expect(fixture.fake.activeSubscriptions == 0)
	}
}
