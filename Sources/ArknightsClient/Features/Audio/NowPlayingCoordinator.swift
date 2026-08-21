// SPDX-License-Identifier: MPL-2.0

import AppKit
import MediaPlayer

@MainActor
protocol NowPlayingInfoPublishing: AnyObject {
	var nowPlayingInfo: [String: Any]? { get set }
	var playbackState: MPNowPlayingPlaybackState { get set }
}

extension MPNowPlayingInfoCenter: NowPlayingInfoPublishing {}

/// Publishes launcher music and the selected launcher icon to macOS Now Playing surfaces.
@MainActor
final class NowPlayingCoordinator {
	private let center: any NowPlayingInfoPublishing
	private var title: String?
	private var artist: String?
	private var artwork: NSImage
	private var isPlaying = false

	init(
		icon: NSImage,
		center: any NowPlayingInfoPublishing = MPNowPlayingInfoCenter.default()
	) {
		artwork = icon
		self.center = center
	}

	func updateTrack(title: String, artist: String?) {
		self.title = title
		self.artist = artist
		publish()
	}

	func updatePlayback(isPlaying: Bool) {
		self.isPlaying = isPlaying
		publish()
	}

	func updateArtwork(_ image: NSImage) {
		artwork = image
		publish()
	}

	func clear() {
		title = nil
		artist = nil
		isPlaying = false
		center.nowPlayingInfo = nil
		center.playbackState = .stopped
	}

	private func publish() {
		guard let title else { return }
		var information: [String: Any] = [
			MPMediaItemPropertyTitle: title,
			MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
			MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
			MPMediaItemPropertyArtwork: Self.mediaArtwork(from: artwork),
		]
		if let artist, !artist.isEmpty {
			information[MPMediaItemPropertyArtist] = artist
		}
		center.nowPlayingInfo = information
		center.playbackState = isPlaying ? .playing : .paused
	}

	private nonisolated static func mediaArtwork(from image: NSImage) -> MPMediaItemArtwork {
		let provider = NowPlayingArtworkProvider(image: image)
		return MPMediaItemArtwork(boundsSize: image.size) { requestedSize in
			provider.image(for: requestedSize)
		}
	}
}
