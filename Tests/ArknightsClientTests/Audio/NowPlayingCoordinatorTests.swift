// SPDX-License-Identifier: MPL-2.0

import AppKit
import MediaPlayer
import Testing

@testable import ArknightsClient

@MainActor
struct NowPlayingCoordinatorTests {
	@Test
	func publishesTrackPlaybackAndLauncherArtwork() {
		let center = RecordingNowPlayingInfoCenter()
		let firstIcon = NSImage(size: NSSize(width: 32, height: 32))
		let replacementIcon = NSImage(size: NSSize(width: 64, height: 64))
		let coordinator = NowPlayingCoordinator(icon: firstIcon, center: center)

		coordinator.updateTrack(title: "Radiant", artist: "Arknights")
		let firstArtwork =
			center.nowPlayingInfo?[MPMediaItemPropertyArtwork]
			as? MPMediaItemArtwork
		coordinator.updatePlayback(isPlaying: true)

		#expect(center.nowPlayingInfo?[MPMediaItemPropertyTitle] as? String == "Radiant")
		#expect(center.nowPlayingInfo?[MPMediaItemPropertyArtist] as? String == "Arknights")
		#expect(center.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 1)
		#expect(center.playbackState == .playing)
		#expect(firstArtwork != nil)

		coordinator.updateArtwork(replacementIcon)
		let replacementArtwork =
			center.nowPlayingInfo?[MPMediaItemPropertyArtwork]
			as? MPMediaItemArtwork
		#expect(replacementArtwork !== firstArtwork)
	}

	@Test
	func clearRemovesSystemMetadataAndStopsPlayback() {
		let center = RecordingNowPlayingInfoCenter()
		let coordinator = NowPlayingCoordinator(
			icon: NSImage(size: NSSize(width: 32, height: 32)),
			center: center
		)
		coordinator.updateTrack(title: "Radiant", artist: nil)
		coordinator.updatePlayback(isPlaying: true)

		coordinator.clear()

		#expect(center.nowPlayingInfo == nil)
		#expect(center.playbackState == .stopped)
	}
}

@MainActor
private final class RecordingNowPlayingInfoCenter: NowPlayingInfoPublishing {
	var nowPlayingInfo: [String: Any]?
	var playbackState: MPNowPlayingPlaybackState = .unknown
}
