// SPDX-License-Identifier: MPL-2.0

import Foundation

enum AppConstants {
	enum Game {
		static let installedStateFileName = ".arknights-client-state.json"
	}

	enum Icon {
		static let canvasDimension: CGFloat = 512
		static let squircleDimension: CGFloat = 412
		static let squircleCornerRadius: CGFloat = 92.3
		static let baseCyanHue: Double = 0.533
		static let operatorFrameInset: CGFloat = 36
		/// Opacity of the dynamically tinted frame drawn over generated Game icons.
		static let operatorFrameOpacity: CGFloat = 1.0
		static let operatorFrameOutlineWidth: CGFloat = 1.5
	}

	enum Music {
		static let defaultLauncherMusicURL =
			"https://www.youtube.com/playlist?list=PLbuSQ8SJFnFEHL4_T9S0whD-TevceJIsl"
		static let backgroundMusicViewFrame: Double = 300
		static let backgroundMusicOpacity: Double = 0.01
		static let backgroundMusicOffscreenOffset: Double = -10_000
		static let skipMetadataPlaceholderTitle = "YouTube"
		static let fadeInDuration: Double = 1.5
		static let fadeOutDuration: Double = 1.0
		static let fadeSteps: Int = 15
		static let playlistShuffleDelay: Duration = .milliseconds(200)
		static let trackChangePollInterval: Duration = .milliseconds(250)
		static let trackChangePollLimit = 80
		static let collapsedTitleMaxWidth: Double = 300
		static let titleLineHeight: Double = 14
		static let titleScrollGap: Double = 24
		static let titleScrollSpeed: Double = 24
		static let titleScrollDelay: Duration = .seconds(1.25)
		static let titleScrollMinimumDuration: Double = 3
		static let collapsedPlayerHeight: Double = 28
		static let expandedPlayerWidth: Double = 330
		static let expandedPlayerHeight: Double = 94
		static let secondaryControlDimension: Double = 34
		static let prominentControlDimension: Double = 38
		static let volumeControlExpandedWidth: Double = 132
		static let volumeSliderWidth: Double = 82
		static let playerExpansionDuration: Double = 0.3
	}

	enum HUD {
		static let collapsedVersionMaxWidth: Double = 150
		static let collapsedVersionTitleMaxWidth: Double = 100
		static let collapsedStatusMaxWidth: Double = 280
		static let collapsedStatusTitleMaxWidth: Double = 210
		static let downloadProgressDetailMinWidth: Double = 132
		static let expandedVersionWidth: Double = 260
		static let expandedVersionHeight: Double = 72
		static let expansionDuration: Double = 0.3
		static let pillRowTrailingInset: Double = 2
	}

	enum Network {
		static let concurrentDownloads = 6
		static let maxDownloadAttempts = 3
		static let retryBackoffStep: Duration = .milliseconds(400)
		/// Network samples shorter than this interval are accumulated before being
		/// converted into a rate. This keeps individual HTTP chunks from making the
		/// displayed speed oscillate.
		static let transferRateSampleInterval: Duration = .milliseconds(250)
		/// A rate must have two comparable samples before it is suitable for ETA.
		static let transferRateMinimumStableSamples = 2
		/// No useful ETA can be inferred after this much time without network data.
		/// This deliberately exceeds a normal file/stream hand-off gap.
		static let transferRateStallTimeout: Duration = .seconds(5)
		/// Re-anchor the projected finish only after a meaningful estimate change.
		static let transferRateEtaHysteresis: Duration = .seconds(10)
		static let transferRateEtaRebaseHorizon: Duration = .seconds(5)
		/// Keep short ETAs precise enough to avoid abrupt minute-boundary jumps.
		static let transferRateEtaMinuteSecondThreshold: Duration = .seconds(600)
		static let transferRateEtaSubminuteQuantum: Duration = .seconds(5)
		static let transferRateEtaMinuteSecondQuantum: Duration = .seconds(10)
		/// Refresh stalled-download state even when the HTTP stream has no new chunks.
		static let transferRateMonitorInterval: Duration = .seconds(1)
		/// Weight of the newest sample in the smoothed transfer rate.
		static let transferRateSmoothingFactor = 0.35
		static let launcherReleaseMaximumBytes = 1 * 1_024 * 1_024
		static let announcementFeedMaximumBytes = 128 * 1_024
		static let yostarAPIResponseMaximumBytes = 4 * 1_024 * 1_024
		static let yostarManifestMaximumBytes = 32 * 1_024 * 1_024
	}

	enum Presets {
		static let characterCatalogMaximumBytes = 32 * 1_024 * 1_024
		static let wallpaperCatalogMaximumBytes = 4 * 1_024 * 1_024
		static let imageMaximumBytes = 24 * 1_024 * 1_024
		static let imageCacheMaximumBytes: Int64 = 256 * 1_024 * 1_024
		static let imageMaximumDimension = 8_192
		static let imageMaximumPixels = 36_000_000
		static let avatarIdentifierMaximumLength = 96
		static let wallpaperPageSize = 50
		static let wallpaperPageLimit = 5
		static let requestTimeout: TimeInterval = 8
	}

	enum IO {
		static let checksumBufferSize = 4 * 1024 * 1024
		static let processDiagnosticMaximumCharacters = 4_096
	}

	enum Logging {
		static let maximumFileSize = 4 * 1_024 * 1_024
		static let maximumMessageBytes = 16 * 1_024
		static let truncationMarker = " [trunc]"
		static let wineLogTailBytes = 2_000
		static let crashReportSearchWindow: TimeInterval = 120
	}

	enum Artwork {
		static let launcherMaximumBytes = 25 * 1_024 * 1_024
		static let officialLogoMaximumBytes = 2 * 1_024 * 1_024
	}

	enum Timeouts {
		static let processTerminateGracePeriod: TimeInterval = 3
		static let processKillGracePeriod: TimeInterval = 1
		static let windowReadiness: Duration = .seconds(90)
		static let windowPollInterval: Duration = .milliseconds(250)
		static let resetCountdownPollInterval: Duration = .seconds(30)
	}

	enum Theme {
		static let wallpaperSampleSide = 32
		static let accentHueBuckets = 24
		// Hero artwork can be anything from near-monochrome to neon: these only exclude
		// true noise (near-gray, near-black, blown-out highlights) when picking a hue.
		static let minimumPixelSaturation = 0.15
		static let minimumPixelBrightness = 0.08
		static let maximumPixelBrightness = 0.97
		// The winning hue's own saturation/brightness are clamped into this range so the
		// rendered accent stays legible against the launcher's dark chrome regardless of
		// how dark, pale, or muted the source artwork actually was.
		static let minimumRenderSaturation = 0.65
		static let maximumRenderSaturation = 0.85
		static let minimumRenderBrightness = 0.80
		static let maximumRenderBrightness = 0.95
		// The HUD glass tint stays near-black but picks up a whisper of the same hue as
		// the accent, instead of being perfectly neutral — subtle, not a second signal color.
		static let backgroundTintSaturation = 0.1
		static let backgroundTintBrightness = 0.1
		static let backgroundTintOpacity = 0.52
	}
}
