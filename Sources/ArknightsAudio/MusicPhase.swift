// SPDX-License-Identifier: MPL-2.0

/// What the launcher wants from the music right now. `off` is the only phase without a player.
enum MusicPhase: Equatable {
	case off
	/// The music should be audible: loading, starting, or playing.
	case playing
	case userPaused
	/// The game window hides the music. `resumes` is false when the user had paused it first.
	case silencedForGame(resumes: Bool)
	/// The player reported failures the launcher cannot work around.
	case unavailable

	var isUserPaused: Bool { self == .userPaused }

	var isUnavailable: Bool { self == .unavailable }

	var isSilencedForGame: Bool {
		if case .silencedForGame = self { return true }
		return false
	}

	func applying(_ event: MusicPhaseEvent) -> MusicPhase {
		switch (self, event) {
		case (_, .stopped):
			.off
		case (_, .sourceLoaded):
			.playing
		case (.off, _):
			.off
		case (.playing, .userPaused):
			.userPaused
		case (.userPaused, .userResumed):
			.playing
		case (.playing, .gameWindowAppeared), (.unavailable, .gameWindowAppeared):
			.silencedForGame(resumes: true)
		case (.userPaused, .gameWindowAppeared):
			.silencedForGame(resumes: false)
		case (.silencedForGame(let resumes), .gameProcessEnded):
			resumes ? .playing : .userPaused
		case (.playing, .playerFailed):
			.unavailable
		case (.unavailable, .playerPlayed):
			.playing
		default:
			self
		}
	}
}

enum MusicPhaseEvent: CaseIterable {
	/// A player was created or a new source was loaded.
	case sourceLoaded
	case userPaused
	case userResumed
	case gameWindowAppeared
	case gameProcessEnded
	case playerFailed
	case playerPlayed
	/// The music was disabled, the URL is invalid, or the player was torn down.
	case stopped
}
