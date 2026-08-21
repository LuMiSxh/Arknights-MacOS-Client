// SPDX-License-Identifier: MPL-2.0

import SwiftUI
import YouTubePlayerKit

/// Keeps the controller's WebKit player mounted while wiring launcher lifecycle changes.
struct BackgroundMusicView: View {
	var model: LauncherViewModel
	var controller: BackgroundMusicController

	var body: some View {
		Group {
			// Keep the WebKit view mounted as long as music is enabled in preferences,
			// even when the game is running. Unmounting it would dismantle the WKWebView
			// and lose playlist position/timestamp when resuming after gameplay.
			if let player = controller.player, model.playsLauncherMusic {
				YouTubePlayerView(player)
					.frame(
						width: AppConstants.Music.backgroundMusicViewFrame,
						height: AppConstants.Music.backgroundMusicViewFrame
					)
					.opacity(AppConstants.Music.backgroundMusicOpacity)
					.offset(
						x: AppConstants.Music.backgroundMusicOffscreenOffset,
						y: AppConstants.Music.backgroundMusicOffscreenOffset
					)
					.allowsHitTesting(false)
					.accessibilityHidden(true)
			}
		}
		.task {
			controller.startIfNeeded()
		}
		.onChange(of: model.phase) { oldPhase, newPhase in
			controller.phaseDidChange(from: oldPhase, to: newPhase)
		}
		.onChange(of: model.launcherMusicURL) { _, _ in
			controller.sourceDidChange()
		}
		.onChange(of: model.playsLauncherMusic) { _, isPlaying in
			controller.enabledDidChange(to: isPlaying)
		}
		.onChange(of: model.launcherMusicVolume) { _, newVolume in
			controller.volumeDidChange(to: newVolume)
		}
		.onChange(of: model.isGameProcessRunning) { _, isRunning in
			controller.gameRunningDidChange(to: isRunning)
		}
		.onDisappear {
			controller.stop()
		}
	}
}
