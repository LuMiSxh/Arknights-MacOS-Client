// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsAudio

@MainActor
struct MusicPhaseTests {
	@Test(
		arguments: [
			(MusicPhase.off, MusicPhaseEvent.sourceLoaded, MusicPhase.playing),
			(.off, .gameWindowAppeared, .off),
			(.playing, .userPaused, .userPaused),
			(.userPaused, .userResumed, .playing),
			(.playing, .gameWindowAppeared, .silencedForGame(resumes: true)),
			(.userPaused, .gameWindowAppeared, .silencedForGame(resumes: false)),
			(.unavailable, .gameWindowAppeared, .silencedForGame(resumes: true)),
			(.silencedForGame(resumes: true), .gameProcessEnded, .playing),
			(.silencedForGame(resumes: false), .gameProcessEnded, .userPaused),
			(.playing, .gameProcessEnded, .playing),
			(.userPaused, .gameProcessEnded, .userPaused),
			(.playing, .playerFailed, .unavailable),
			(.userPaused, .playerFailed, .userPaused),
			(.silencedForGame(resumes: true), .playerFailed, .silencedForGame(resumes: true)),
			(.unavailable, .playerPlayed, .playing),
			(.userPaused, .playerPlayed, .userPaused),
			(.silencedForGame(resumes: false), .playerPlayed, .silencedForGame(resumes: false)),
			(.unavailable, .userResumed, .unavailable),
			(.silencedForGame(resumes: true), .stopped, .off),
			(.unavailable, .stopped, .off),
		] as [(MusicPhase, MusicPhaseEvent, MusicPhase)]
	)
	func eventsMovePlaybackBetweenPhases(
		from phase: MusicPhase,
		event: MusicPhaseEvent,
		expected: MusicPhase
	) {
		#expect(phase.applying(event) == expected)
	}
}
