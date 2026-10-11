// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import Foundation
import Observation
import SwiftUI

/// Owns launcher artwork, Dynamic Theme, and launcher/game icon customizations.
@MainActor
@Observable
package final class CustomizationController {
	typealias DataLoader = @Sendable (URL) async throws -> Data
	typealias DataStager = @Sendable (Data, URL) async throws -> Void
	typealias IconCommitter = @Sendable (URL, URL) throws -> Void
	typealias IconPublicationPreparer =
		@Sendable ([URL], UUID, LauncherLog) async throws
		-> CustomizationImageIO.PreparedPublication
	typealias AccentExtractor = @MainActor @Sendable (NSImage) async -> ExtractedAccent?
	typealias DynamicIconRenderer = @MainActor (Double) -> NSImage?

	let lifecycle: LauncherLifecycleStore
	package let paths: AppPaths
	let preferences: LauncherPreferencesStore
	package let log: LauncherLog
	package let artworkCache: ArtworkCache
	package let launcherIconManager: LauncherIconManager
	package let region: @MainActor () -> GameRegion
	package let usesDynamicTheme: @MainActor () -> Bool

	package var heroArtwork: NSImage? {
		didSet { updateThemeColor() }
	}
	package var officialLogo: NSImage?
	package private(set) var hasCustomAppIcon = false
	package private(set) var hasCompletedInitialArtworkLoad = false
	package private(set) var hasCustomGameIcon = false
	/// Flips once `restoreInitialArtwork(for:)` finishes, so the launcher window can stay
	/// hidden until it has real wallpaper/logo to show instead of a placeholder.
	package var dynamicThemeHue: Double?
	package var accentColor: Color = LauncherVisuals.cyan
	package var hudTintColor: Color = LauncherVisuals.hudGlassTint
	package private(set) var activeThemeCacheKey: String?
	/// Increments only when the persisted custom artwork changes. Branding refreshes use this
	/// generation to reject an official image that was already in flight when the user chose a
	/// custom image.
	package private(set) var customArtworkGeneration: UInt64 = 0
	package private(set) var hasPersistedCustomArtwork = false
	let dataLoader: DataLoader
	let dataStager: DataStager
	let iconCommitter: IconCommitter
	let iconPublicationPreparer: IconPublicationPreparer
	let accentExtractor: AccentExtractor
	let dynamicIconRenderer: DynamicIconRenderer
	@ObservationIgnored var artworkOperationID: UUID?
	@ObservationIgnored var passiveArtworkOperationID: UUID?
	@ObservationIgnored var artworkMutationInFlight = false
	@ObservationIgnored var themeOperationID: UUID?
	@ObservationIgnored var operatorIconOperationID: UUID?
	@ObservationIgnored var passiveOperatorIconOperationID: UUID?
	@ObservationIgnored var iconMutationGeneration: UInt64 = 0
	@ObservationIgnored var iconMutationInFlight = false
	@ObservationIgnored var iconRestoreOperationID: UUID?
	@ObservationIgnored var officialLogoOperationID: UUID?

	func customArtworkDidChange() {
		customArtworkGeneration &+= 1
	}

	func setHasPersistedCustomArtwork(_ value: Bool) {
		hasPersistedCustomArtwork = value
	}

	func setHasCustomAppIcon(_ value: Bool) {
		hasCustomAppIcon = value
	}

	func setHasCustomGameIcon(_ value: Bool) {
		hasCustomGameIcon = value
	}

	package func markInitialArtworkLoadComplete() {
		hasCompletedInitialArtworkLoad = true
	}

	package convenience init(
		lifecycle: LauncherLifecycleStore,
		paths: AppPaths,
		preferences: LauncherPreferencesStore,
		log: LauncherLog? = nil,
		artworkCache: ArtworkCache? = nil,
		launcherIconManager: LauncherIconManager,
		region: @escaping @MainActor () -> GameRegion,
		usesDynamicTheme: @escaping @MainActor () -> Bool
	) {
		self.init(
			lifecycle: lifecycle,
			paths: paths,
			preferences: preferences,
			log: log,
			artworkCache: artworkCache,
			launcherIconManager: launcherIconManager,
			region: region,
			usesDynamicTheme: usesDynamicTheme,
			dataLoader: nil
		)
	}

	/// Designated initializer. Tests inject the I/O and rendering seams through it.
	init(
		lifecycle: LauncherLifecycleStore,
		paths: AppPaths,
		preferences: LauncherPreferencesStore,
		log: LauncherLog? = nil,
		artworkCache: ArtworkCache? = nil,
		launcherIconManager: LauncherIconManager,
		region: @escaping @MainActor () -> GameRegion,
		usesDynamicTheme: @escaping @MainActor () -> Bool,
		dataLoader: DataLoader? = nil,
		dataStager: DataStager? = nil,
		iconCommitter: IconCommitter? = nil,
		iconPublicationPreparer: IconPublicationPreparer? = nil,
		accentExtractor: AccentExtractor? = nil,
		dynamicIconRenderer: DynamicIconRenderer? = nil
	) {
		self.lifecycle = lifecycle
		self.paths = paths
		self.preferences = preferences
		self.log = log ?? lifecycle.log
		self.artworkCache = artworkCache ?? ArtworkCache(directory: paths.artworkCache)
		self.launcherIconManager = launcherIconManager
		self.region = region
		self.usesDynamicTheme = usesDynamicTheme
		self.dataLoader = dataLoader ?? CustomizationImageIO.load
		self.dataStager = dataStager ?? CustomizationImageIO.stage
		self.iconCommitter = iconCommitter ?? CustomizationImageIO.commit
		self.iconPublicationPreparer =
			iconPublicationPreparer
			?? CustomizationImageIO.preparePublication
		self.accentExtractor = accentExtractor ?? WallpaperColorExtractor.extractAccent
		self.dynamicIconRenderer = dynamicIconRenderer ?? AppIconRenderer.tintedDefaultIcon
	}

	package static func officialThemeCacheKey(
		for region: GameRegion, artworkCacheKey: String
	)
		-> String
	{
		"official.\(region.rawValue).\(artworkCacheKey)"
	}

	package func setHeroArtwork(_ image: NSImage?, themeCacheKey: String?) {
		guard heroArtwork == nil || activeThemeCacheKey != themeCacheKey else { return }
		activeThemeCacheKey = themeCacheKey
		heroArtwork = image
	}
}
