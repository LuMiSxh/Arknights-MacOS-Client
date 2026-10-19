// SPDX-License-Identifier: MPL-2.0

import Foundation

package enum AppConstants {
	package enum Game {
		package static let installedStateFileName = ".arknights-client-state.json"
		package static let installedStateMaximumBytes = 8 * 1_024 * 1_024
		package static let installerStagingDirectoryName = ".arknights-client-install-staging"
		package static let installerResumeMetadataMaximumBytes = 16 * 1_024
		package static let runtimeMigrationStateMaximumBytes = 64 * 1_024
		package static let userDirectoryConfigurationMaximumBytes = 64 * 1_024
		package static let vuplexOfficialHelperMaximumBytes = 5 * 1_024 * 1_024
		package static let vuplexShimMaximumBytes = 1 * 1_024 * 1_024
		package static let platformProcessAssetMaximumBytes = 4 * 1_024 * 1_024
		package static let bilibiliPlatformAssetMaximumBytes = 16 * 1_024 * 1_024
		/// Title bar height assumed when the real one cannot be measured.
		static let standardWindowTitleBarHeight: CGFloat = 28
		/// Share of the usable screen the "leave room" game window may cover.
		static let compactWindowScreenShare = 0.65
		static let generatedResolutionHeightStep = 360
		/// Smallest on-screen window treated as the game window; smaller helper windows are ignored.
		package static let minimumGameWindowWidth: Double = 320
		package static let minimumGameWindowHeight: Double = 200
	}

	package enum Runtime {
		static let aceCompactEnvironmentKey = "ARKNIGHTS_RUNTIME_ACE_COMPACT"
		static let cefCompatEnvironmentKey = "ARKNIGHTS_RUNTIME_CEF_COMPAT"
		static let cnCompatEnvironmentKey = "ARKNIGHTS_RUNTIME_CN_COMPAT"
		package static let hardwareCursorEnvironmentKey = "ARKNIGHTS_RUNTIME_HARDWARE_CURSOR"
		/// DXMT's upstream switch for its MetalFX spatial-upscaling swapchain.
		package static let metalFXSpatialUpscalingEnvironmentKey = "DXMT_METALFX_SPATIAL_SWAPCHAIN"
		package static let capabilityManifestMaximumBytes = 4 * 1_024
	}

	package enum Icon {
		package static let canvasDimension: CGFloat = 512
		package static let squircleDimension: CGFloat = 412
		/// Pixels per point for rendered icons, fixed so output never depends on the focused screen.
		package static let renderScale: CGFloat = 2
		package static let squircleCornerRadius: CGFloat = 92.3
		package static let baseCyanHue: Double = 0.533
		package static let operatorFrameInset: CGFloat = 36
		package static let operatorFrameOpacity: CGFloat = 1.0
		package static let operatorFrameOutlineWidth: CGFloat = 1.5
		package static let launcherAccentSaturation: CGFloat = 0.9
		package static let launcherBackgroundStart: (red: CGFloat, green: CGFloat, blue: CGFloat) =
			(0.035, 0.055, 0.065)
		package static let launcherBackgroundEnd: (red: CGFloat, green: CGFloat, blue: CGFloat) =
			(0.07, 0.075, 0.085)
		package static let launcherAvatarInsetX: CGFloat = 18
		package static let launcherAvatarInsetY: CGFloat = 12
		package static let launcherBevelOpacity: CGFloat = 0.42
		package static let gameBevelOpacity: CGFloat = 0.16
		package static let shadowOpacity: CGFloat = 0.35
		package static let shadowOffset: CGFloat = 6
		package static let shadowBlurRadius: CGFloat = 12
		package static let specularOpacity: CGFloat = 0.2
		package static let specularHeightFraction: CGFloat = 0.55
		/// Below this, a newly resolved hue is treated as unchanged from the persisted icon's.
		package static let dynamicIconHueChangeTolerance: Double = 0.02
	}

	package enum Music {
		static let defaultLauncherMusicURL =
			"https://www.youtube.com/playlist?list=PLbuSQ8SJFnFEHL4_T9S0whD-TevceJIsl"
		package static let backgroundMusicViewFrame: Double = 300
		package static let backgroundMusicOpacity: Double = 0.01
		package static let backgroundMusicOffscreenOffset: Double = -10_000
		package static let skipMetadataPlaceholderTitle = "YouTube"
		package static let fadeInDuration: Double = 1.5
		package static let fadeOutDuration: Double = 1.0
		package static let fadeSteps: Int = 15
		package static let playlistShuffleDelay: Duration = .milliseconds(200)
		package static let sourceChangeDebounce: Duration = .milliseconds(300)
		package static let trackChangePollInterval: Duration = .milliseconds(250)
		package static let trackChangePollLimit = 80
		package static let collapsedTitleMaxWidth: Double = 300
		package static let titleLineHeight: Double = 14
		package static let titleScrollGap: Double = 24
		package static let titleScrollSpeed: Double = 24
		package static let titleScrollDelay: Duration = .seconds(1.25)
		package static let titleScrollMinimumDuration: Double = 3
		package static let collapsedPlayerHeight: Double = 28
		package static let expandedPlayerWidth: Double = 330
		package static let expandedPlayerHeight: Double = 94
		package static let secondaryControlDimension: Double = 34
		package static let prominentControlDimension: Double = 38
		package static let volumeControlExpandedWidth: Double = 132
		package static let volumeSliderWidth: Double = 82
	}

	package enum Storage {
		/// Reuse a completed directory measurement briefly while Settings is reopened, while
		/// allowing later installs, repairs, and external cache changes to become visible.
		package static let overviewCacheLifetime: TimeInterval = 30
	}

	package enum Settings {
		package static let minWidth: Double = 760
		package static let minHeight: Double = 520
		package static let maxWidth: Double = 820
		package static let maxHeight: Double = 570
		package static let windowMargin: Double = 24
	}

	package enum HUD {
		package static let collapsedVersionMaxWidth: Double = 150
		package static let collapsedVersionTitleMaxWidth: Double = 100
		package static let collapsedStatusMaxWidth: Double = 280
		package static let collapsedStatusTitleMaxWidth: Double = 210
		package static let expandedStatusMinWidth: Double = 240
		package static let expandedStatusWidth: Double = 360
		package static let downloadProgressDetailMinWidth: Double = 132
		package static let downloadSpeedDetailMinWidth: Double = 84
		package static let expandedVersionWidth: Double = 260
		package static let expandedVersionHeight: Double = 72
		package static let pillRowTrailingInset: Double = 2
	}

	package enum Network {
		package static let concurrentDownloads = 6
		package static let maxDownloadAttempts = 3
		package static let retryBackoffStep: Duration = .milliseconds(400)
		/// Network samples shorter than this interval are accumulated before being
		/// converted into a rate. This keeps individual HTTP chunks from making the
		/// displayed speed oscillate.
		package static let transferRateSampleInterval: Duration = .milliseconds(250)
		package static let progressEmissionInterval: Duration = .milliseconds(100)
		/// No useful rate can be inferred after this much time without network data.
		/// This deliberately exceeds a normal file/stream hand-off gap.
		package static let transferRateStallTimeout: Duration = .seconds(5)
		/// Refresh stalled-download state even when the HTTP stream has no new chunks.
		package static let transferRateMonitorInterval: Duration = .seconds(1)
		package static let transferRateSmoothingFactor = 0.35
		package static let maximumBufferedStreamBytes = 8 * 1_024 * 1_024
		package static let announcementFeedMaximumBytes = 128 * 1_024
		package static let yostarAPIResponseMaximumBytes = 4 * 1_024 * 1_024
		package static let yostarManifestMaximumBytes = 32 * 1_024 * 1_024
	}

	package enum Presets {
		package static let characterCatalogMaximumBytes = 32 * 1_024 * 1_024
		package static let wallpaperCatalogMaximumBytes = 4 * 1_024 * 1_024
		package static let wallpaperTagsMaximumBytes = 1_024 * 1_024
		/// The repository's current tag manifest, so tags for new wallpapers ship without a release.
		/// App-owned, so it follows `main` on purpose and is not pinned. Bound: `wallpaperTagsMaximumBytes`.
		/// Fallback: the bundled and cached tags.
		package static let wallpaperTagsURL = URL(
			string:
				"https://raw.githubusercontent.com/LuMiSxh/Arknights-MacOS-Client/main/Sources/ArknightsCore/Resources/WallpaperTags.json"
		)!
		package static let imageMaximumBytes = 24 * 1_024 * 1_024
		package static let imageCacheMaximumBytes: Int64 = 256 * 1_024 * 1_024
		/// In-memory decoded gallery thumbnails; `NSCache` cost is bytes.
		package static let thumbnailCacheMaximumBytes = 32 * 1_024 * 1_024
		/// In-memory rendered Launcher and Game icon pairs (about 8 MiB each).
		package static let iconPairCacheMaximumBytes = 48 * 1_024 * 1_024
		package static let imageDownloadAttempts = 2
		package static let imageMaximumDimension = 16_384
		package static let imageMaximumPixels = 120_000_000
		// Matches the exact percentage the live Fankit gallery page itself requests, since
		// the CDN only ever serves a resized response for a URL something has already
		// requested with this precise query value — see syntheticThumbnailURL(for:).
		package static let thumbnailResizePercent = 50
		package static let avatarIdentifierMaximumLength = 96
		package static let wallpaperPageSize = 50
		package static let wallpaperPageLimit = 5
		package static let gallerySuggestionLimit = 6
		package static let requestTimeout: TimeInterval = 8
	}

	package enum IO {
		package static let checksumBufferSize = 4 * 1024 * 1024
		package static let fileComparisonBufferSize = 1 * 1_024 * 1_024
		/// Files hashed at once during the check pass; bounds open descriptors and read buffers.
		package static let verificationConcurrency = 4
		package static let processDiagnosticMaximumBytes = 16 * 1_024
		package static let processDiagnosticMaximumCharacters = 4_096
	}

	package enum Logging {
		package static let installerSignpostCategory = "Installer"
		static let maximumFileSize = 4 * 1_024 * 1_024
		static let maximumMessageBytes = 16 * 1_024
		static let truncationMarker = " [trunc]"
		package static let wineLogTailBytes = 2_000
		package static let crashReportSearchWindow: TimeInterval = 120
	}

	package enum Playtime {
		package static let schemaVersion = 1
		static let statisticsFilename = "playtime-v1.json"
		package static let statisticsMaximumBytes = 64 * 1_024
		package static let dailyHistoryLimit = 31
	}

	package enum Artwork {
		package static let launcherMaximumBytes = 25 * 1_024 * 1_024
		package static let officialLogoMaximumBytes = 2 * 1_024 * 1_024
		package static let maximumDimension = 8_192
		package static let maximumPixels = 36_000_000
	}

	package enum Timeouts {
		package static let processTerminateGracePeriod: TimeInterval = 3
		package static let processKillGracePeriod: TimeInterval = 1
		package static let processRetirementPollInterval: Duration = .milliseconds(25)
		/// Covers helper retirement and final wineserver verification before prefix ownership ends.
		package static let runtimeShutdown: Duration = .seconds(20)
		package static let windowReadiness: Duration = .seconds(90)
		package static let windowPollInterval: Duration = .milliseconds(250)
		package static let quitSheetDetachPollInterval: TimeInterval = 0.05
		package static let quitSheetDetachPollLimit = 20
	}

	package enum Theme {
		package static let wallpaperSampleSide = 32
		package static let accentHueBuckets = 24
		// Hero artwork can be anything from near-monochrome to neon: these only exclude
		// true noise (near-gray, near-black, blown-out highlights) when picking a hue.
		// Muted pixels are excluded here and weighted down further in the accent score.
		package static let minimumPixelSaturation = 0.25
		package static let minimumPixelBrightness = 0.08
		package static let maximumPixelBrightness = 0.97
		// The winning hue's own saturation/brightness are clamped into this range so the
		// rendered accent stays legible against the launcher's dark chrome regardless of
		// how dark, pale, or muted the source artwork actually was.
		package static let minimumRenderSaturation = 0.65
		package static let maximumRenderSaturation = 0.85
		package static let minimumRenderBrightness = 0.80
		package static let maximumRenderBrightness = 0.95
		// The HUD glass tint stays near-black but picks up a whisper of the same hue as
		// the accent, instead of being perfectly neutral — subtle, not a second signal color.
		package static let backgroundTintSaturation = 0.1
		package static let backgroundTintBrightness = 0.1
		package static let backgroundTintOpacity = 0.52
	}
}
