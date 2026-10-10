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
	static let settingsTitle = "Audio"
	static let settingsSubtitle = "Music while the launcher is open"
	static let settingsMusic = "Music"
	static let settingsBackgroundMusic = "Play background music"
	static let settingsBackgroundMusicDetail =
		"Plays music while the launcher is open and the game is closed."
	static let settingsURL = "Music URL"
	static let settingsURLDetail = "A YouTube video or playlist link."
	static let settingsURLPrompt = "https://www.youtube.com/playlist?..."
	static let settingsVolume = "Volume"
	static let settingsVolumeDetail = "How loud the launcher music plays."
	static let settingsCurrentlyPlaying = "Show what's playing"
	static let settingsCurrentlyPlayingDetail =
		"Shows the current track and playback controls on the launcher."

	static func volumePercent(_ percent: Int) -> String {
		"\(percent) percent"
	}

	static func settingsVolumePercent(_ percentage: Int) -> String {
		"\(percentage)%"
	}

	static func playlistTrack(_ number: Int) -> String {
		"Playlist track \(number)"
	}
}
