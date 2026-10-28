// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsAudio

@MainActor
struct BackgroundMusicTitleTests {
	@Test
	func metadataEventOutsideATrackChangeUpdatesTheTitle() async throws {
		let fixture = try MusicFixture()
		defer { fixture.remove() }
		let controller = fixture.controller
		controller.observeEvents(of: try #require(controller.player))

		fixture.fake.emit(.metadata(try FakeMusicPlayer.metadata(videoID: "a", title: "First")))
		#expect(await waitForCondition { controller.currentMusicTitle == "First" })
		fixture.fake.emit(.metadata(try FakeMusicPlayer.metadata(videoID: "b", title: "Second")))
		#expect(await waitForCondition { controller.currentMusicTitle == "Second" })
	}

	@Test
	func titleIsReadFromThePlayerWhenATrackStartsPlayingAfterAStaleMetadataEvent() async throws {
		let fixture = try MusicFixture()
		defer { fixture.remove() }
		let controller = fixture.controller
		controller.observeEvents(of: try #require(controller.player))
		fixture.fake.emit(.metadata(try FakeMusicPlayer.metadata(videoID: "a", title: "First")))
		#expect(await waitForCondition { controller.currentMusicTitle == "First" })

		// YouTube can announce the new video before it serves the new video's data.
		fixture.fake.metadata = try FakeMusicPlayer.metadata(videoID: "b", title: "Second")
		fixture.fake.emit(.playback(.playing))

		#expect(await waitForCondition { controller.currentMusicTitle == "Second" })
	}
}
