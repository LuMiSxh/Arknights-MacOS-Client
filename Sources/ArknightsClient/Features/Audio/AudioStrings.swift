// SPDX-License-Identifier: MPL-2.0

import Foundation

enum AudioStrings {
	static let hideControls = LocalizedStringResource.audioControlsHide
	static let showControls = LocalizedStringResource.audioControlsShow
	static let previousTrack = LocalizedStringResource.audioControlsPrevious
	static let pause = LocalizedStringResource.audioControlsPause
	static let play = LocalizedStringResource.audioControlsPlay
	static let nextTrack = LocalizedStringResource.audioControlsNext
	static let openYouTube = LocalizedStringResource.audioControlsOpenYouTube
	static let pausedForGame = LocalizedStringResource.audioStatusPausedForGame
	static let changingTrack = LocalizedStringResource.audioStatusChangingTrack
	static let playing = LocalizedStringResource.audioStatusPlaying
	static let paused = LocalizedStringResource.audioStatusPaused
	static let muted = LocalizedStringResource.audioVolumeMuted
	static let volume = LocalizedStringResource.audioVolumeLabel
	static let unmute = LocalizedStringResource.audioVolumeUnmute
	static let mute = LocalizedStringResource.audioVolumeMute

	static func volumePercent(_ percent: Int) -> LocalizedStringResource {
		.audioVolumePercent(percent)
	}
}
