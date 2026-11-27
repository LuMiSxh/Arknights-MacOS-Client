// SPDX-License-Identifier: MPL-2.0

import AVFoundation
import AppKit
import SwiftUI

// Draws the custom background video. The player pauses and rewinds to its first frame, so the
// poster still underneath matches the paused picture.
struct LauncherVideoBackground: NSViewRepresentable {
	let url: URL
	let isPlaying: Bool

	func makeNSView(context: Context) -> LauncherVideoLayerView {
		let view = LauncherVideoLayerView(url: url)
		view.setPlaying(isPlaying)
		return view
	}

	func updateNSView(_ view: LauncherVideoLayerView, context: Context) {
		view.setPlaying(isPlaying)
	}

	static func dismantleNSView(_ view: LauncherVideoLayerView, coordinator: Void) {
		view.stop()
	}
}

@MainActor
final class LauncherVideoLayerView: NSView {
	private let player: AVQueuePlayer
	private let looper: AVPlayerLooper
	private let playerLayer: AVPlayerLayer
	private var isPlaying = false

	init(url: URL) {
		let player = AVQueuePlayer()
		player.isMuted = true
		// A decorative background must not keep the display awake.
		player.preventsDisplaySleepDuringVideoPlayback = false
		self.player = player
		looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
		playerLayer = AVPlayerLayer(player: player)
		playerLayer.videoGravity = .resizeAspectFill
		super.init(frame: .zero)
		wantsLayer = true
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func makeBackingLayer() -> CALayer {
		playerLayer
	}

	func setPlaying(_ playing: Bool) {
		guard playing != isPlaying else { return }
		isPlaying = playing
		if playing {
			player.play()
		} else {
			player.pause()
			player.seek(to: .zero)
		}
	}

	func stop() {
		looper.disableLooping()
		player.pause()
	}
}
