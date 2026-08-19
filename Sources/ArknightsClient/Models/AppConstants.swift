// SPDX-License-Identifier: MPL-2.0

import Foundation

enum AppConstants {
	enum Music {
		static let defaultLauncherMusicURL =
			"https://www.youtube.com/playlist?list=PLFxi1xOJXheF2zXThZTQnInoWZb1JfPf5"
		static let nowPlayingPrefix = "♫ "
		static let nowPlayingTitleMaxWidth: Double = 160
		static let backgroundMusicViewFrame: Double = 300
		static let backgroundMusicOpacity: Double = 0.01
		static let skipMetadataPlaceholderTitle = "YouTube"
		static let fadeInDuration: Double = 1.5
		static let fadeOutDuration: Double = 1.0
		static let fadeSteps: Int = 15
		static let playlistShuffleDelay: Duration = .milliseconds(200)
	}

	enum Network {
		static let concurrentDownloads = 6
		static let maxDownloadAttempts = 3
		static let retryBackoffStep: Duration = .milliseconds(400)
	}

	enum IO {
		static let checksumBufferSize = 4 * 1024 * 1024
	}

	enum Timeouts {
		static let processTerminateGracePeriod: TimeInterval = 3
		static let processKillGracePeriod: TimeInterval = 1
		static let windowReadiness: Duration = .seconds(90)
		static let windowPollInterval: Duration = .milliseconds(250)
		static let resetCountdownPollInterval: Duration = .seconds(30)
	}
}
