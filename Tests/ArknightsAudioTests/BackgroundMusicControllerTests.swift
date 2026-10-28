// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsCustomization
import ArknightsTestSupport
import Foundation
import Testing
import YouTubePlayerKit

@testable import ArknightsAudio

@MainActor
struct BackgroundMusicControllerTests {
	@Test
	func newerPlayIntentIgnoresALatePausedStateFromThePreviousRequest() throws {
		let fixture = try MusicFixture()
		defer { fixture.remove() }
		let controller = fixture.controller

		let player = YouTubePlayer(source: .video(id: "test"))
		controller.player = player
		let pauseOperation = controller.beginOperation(.playbackChange(.paused))
		controller.expectPlayback(.paused)
		controller.finishOperation(pauseOperation)

		let playOperation = controller.beginOperation(.playbackChange(.playing))
		controller.expectPlayback(.playing)
		controller.finishOperation(playOperation)
		controller.playbackState = .paused
		controller.reconcilePlaybackIntent(with: .paused)

		#expect(controller.playbackIntent == .playing)
		#expect(controller.isPlaying)

		controller.playbackState = .buffering
		controller.reconcilePlaybackIntent(with: .buffering)
		#expect(controller.playbackIntent == nil)
		#expect(controller.isPlaying)
	}
}
