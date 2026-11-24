// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI
import YouTubePlayerKit

/// Keeps the controller's WebKit player mounted while the view is on screen.
package struct BackgroundMusicView: View {
	let settings: LauncherPreferencesController
	let controller: BackgroundMusicController

	package init(
		settings: LauncherPreferencesController,
		controller: BackgroundMusicController
	) {
		self.settings = settings
		self.controller = controller
	}

	package var body: some View {
		// A ZStack, not a Group: while there is no player the content is empty, and `.task` and
		// `.onDisappear` never run on an empty Group, so the controller would never start.
		ZStack {
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
			controller.start()
		}
		.onDisappear {
			controller.stop()
		}
	}
}
