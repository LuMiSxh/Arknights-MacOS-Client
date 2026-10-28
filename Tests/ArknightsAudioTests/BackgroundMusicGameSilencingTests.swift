// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsAudio

@MainActor
struct BackgroundMusicGameSilencingTests {
	@Test
	func trackChangeInFlightIssuesNoPlayerCommandAfterTheGameWindowAppears() async throws {
		let fixture = try MusicFixture()
		defer { fixture.remove() }
		let controller = fixture.controller
		controller.currentSource = .playlist(id: "list")
		fixture.fake.holdsMetadata = true

		controller.playNextTrack()
		#expect(await waitForCondition { fixture.fake.isHoldingMetadata })
		controller.gameActivityDidChange(to: .testRunningGame())
		fixture.fake.releaseMetadata()
		#expect(await waitForCondition { fixture.fake.count("pause") == 1 })
		// Give the cancelled track change time to run its remaining steps.
		for _ in 0..<20 { await Task.yield() }

		let commands = fixture.fake.commands
		#expect(!commands.contains("nextVideo"))
		#expect(!controller.isChangingTrack)
	}

	@Test(arguments: [false, true])
	func musicFadesBackInAfterTheGameExitsOnlyWhenNotPausedByTheUser(
		userPaused: Bool
	) async throws {
		let fixture = try MusicFixture()
		defer { fixture.remove() }
		let controller = fixture.controller
		controller.settings.playsLauncherMusic = true

		controller.gameActivityDidChange(to: .testRunningGame())
		#expect(await waitForCondition { fixture.fake.count("pause") == 1 })
		controller.phase = .silencedForGame(resumes: !userPaused)
		controller.gameActivityDidChange(to: .idle)
		for _ in 0..<50 { await Task.yield() }

		#expect(fixture.fake.count("play") == (userPaused ? 0 : 1))
	}

	@Test
	func launchStoppedBeforeTheGameWindowAppearsNeverTouchesTheMusic() async throws {
		let fixture = try MusicFixture()
		defer { fixture.remove() }
		let controller = fixture.controller
		controller.settings.playsLauncherMusic = true

		controller.gameActivityDidChange(to: .preparingGame(sessionID: UUID()))
		controller.gameActivityDidChange(
			to: .launchingGame(sessionID: UUID(), processIdentifier: 1)
		)
		controller.gameActivityDidChange(to: .idle)
		for _ in 0..<50 { await Task.yield() }

		#expect(fixture.fake.commands.isEmpty)
	}

	@Test
	func aSourceLoadFinishingWhileTheGameLaunchesStartsNothing() async throws {
		let fixture = try MusicFixture()
		defer { fixture.remove() }
		let controller = fixture.controller
		controller.currentSource = .playlist(id: "list")
		_ = controller.lifecycle.begin(.launchingGame(sessionID: UUID(), processIdentifier: 1))

		controller.performFadeIn()
		for _ in 0..<50 { await Task.yield() }

		#expect(fixture.fake.commands.isEmpty)
		#expect(controller.fadeTask == nil)
		#expect(controller.playbackIntent == nil)
	}

	@Test
	func muteDuringTheFadeOutStillPausesTheMusic() async throws {
		let fixture = try MusicFixture()
		defer { fixture.remove() }
		let controller = fixture.controller

		controller.gameActivityDidChange(to: .testRunningGame())
		controller.toggleMute()

		#expect(await waitForCondition { fixture.fake.count("pause") == 1 })
		#expect(await waitForCondition { controller.fadeTask == nil })
	}
}
