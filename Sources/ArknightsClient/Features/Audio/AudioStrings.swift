// SPDX-License-Identifier: MPL-2.0

enum AudioStrings {
	static let hideControls = "Hide music controls"
	static let showControls = "Show music controls"
	static let previousTrack = "Previous Track"
	static let pause = "Pause"
	static let play = "Play"
	static let nextTrack = "Next Track"
	static let openYouTube = "Open on YouTube"
	static let pausedForGame = "Paused while the game is running"
	static let changingTrack = "Changing track…"
	static let playing = "Playing"
	static let paused = "Paused"
	static let muted = "Muted"
	static let volume = "Music volume"
	static let unmute = "Unmute music"
	static let mute = "Mute music"

	static func volumePercent(_ percent: Int) -> String {
		"\(percent) percent"
	}

	static func playlistTrack(_ number: Int) -> String {
		"Playlist track \(number)"
	}
}
