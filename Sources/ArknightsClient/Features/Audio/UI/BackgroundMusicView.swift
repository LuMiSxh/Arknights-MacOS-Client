// SPDX-License-Identifier: MPL-2.0

import SwiftUI
import YouTubePlayerKit

/// Keeps the controller's WebKit player mounted while wiring launcher lifecycle changes.
struct BackgroundMusicView: View {
	let lifecycle: LauncherLifecycleStore
	let settings: LauncherPreferencesController
	let gameSession: GameSessionController
	let controller: BackgroundMusicController

	var body: some View {
		Group {
			// Keep the WebKit view mounted as long as music is enabled in preferences,
			// even when the game is running. Unmounting it would dismantle the WKWebView
			// and lose playlist position/timestamp when resuming after gameplay.
			if let player = controller.player, settings.playsLauncherMusic {
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
		.onChange(of: lifecycle.phase) { oldPhase, newPhase in
			controller.phaseDidChange(from: oldPhase, to: newPhase)
		}
		.onChange(of: settings.launcherMusicURL) { _, _ in
			controller.sourceDidChange()
		}
		.onChange(of: settings.playsLauncherMusic) { _, isPlaying in
			controller.enabledDidChange(to: isPlaying)
		}
		.onChange(of: settings.launcherMusicVolume) { _, newVolume in
			controller.volumeDidChange(to: newVolume)
		}
		.onChange(of: gameSession.isGameProcessRunning) { _, isRunning in
			controller.gameRunningDidChange(to: isRunning)
		}
		.onDisappear {
			controller.stop()
		}
	}
}
