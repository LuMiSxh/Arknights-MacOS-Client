// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsAudio

@MainActor
struct BackgroundMusicGameSilencingTests {
	@Test(arguments: [false, true])
	func musicFadesBackInAfterTheGameExitsOnlyWhenNotPausedByTheUser(
		userPaused: Bool
	) async throws {
		let fixture = try MusicFixture()
		defer { fixture.remove() }
		let controller = fixture.controller
		controller.settings.playsLauncherMusic = true

		controller.gameActivityDidChange(to: .testRunningGame())
		await waitForCondition { fixture.fake.count("pause") == 1 }
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
	func muteDuringTheFadeOutStillPausesTheMusic() async throws {
		let fixture = try MusicFixture()
		defer { fixture.remove() }
		let controller = fixture.controller

		controller.gameActivityDidChange(to: .testRunningGame())
		controller.toggleMute()

		await waitForCondition { fixture.fake.count("pause") == 1 }
		if let fadeTask = controller.fadeTask { await fadeTask.value }
	}
}
