// SPDX-License-Identifier: MPL-2.0

import AppKit
import MediaPlayer
import Testing

@testable import ArknightsAudio

@MainActor
struct NowPlayingCoordinatorTests {
	@Test
	func artworkCanBeRequestedFromMediaPlayersPrivateQueue() async {
		let center = RecordingNowPlayingInfoCenter()
		let coordinator = NowPlayingCoordinator(
			icon: NSImage(size: NSSize(width: 32, height: 32)),
			center: center
		)
		coordinator.updateTrack(title: "Radiant", artist: nil)
		guard
			let artwork = center.nowPlayingInfo?[MPMediaItemPropertyArtwork]
				as? MPMediaItemArtwork
		else {
			Issue.record("Expected published media artwork")
			return
		}
		let callback = SendableMediaArtwork(artwork)

		let image = await Task.detached {
			callback.artwork.image(at: NSSize(width: 128, height: 128))
		}.value

		#expect(image != nil)
	}
}

@MainActor
private final class RecordingNowPlayingInfoCenter: NowPlayingInfoPublishing {
	var nowPlayingInfo: [String: Any]?
	var playbackState: MPNowPlayingPlaybackState = .unknown
}

private final class SendableMediaArtwork: @unchecked Sendable {
	let artwork: MPMediaItemArtwork

	init(_ artwork: MPMediaItemArtwork) {
		self.artwork = artwork
	}
}
