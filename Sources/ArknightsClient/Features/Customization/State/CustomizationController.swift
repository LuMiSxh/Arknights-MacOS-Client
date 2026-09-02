// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import Observation
import SwiftUI

/// Owns launcher artwork, Dynamic Theme, and launcher/game icon customizations.
@MainActor
@Observable
final class CustomizationController {
	typealias DataLoader = @Sendable (URL) async throws -> Data
	typealias DataStager = @Sendable (Data, URL) async throws -> Void
	typealias AccentExtractor = @MainActor @Sendable (NSImage) async -> ExtractedAccent?

	let lifecycle: LauncherLifecycleStore
	let paths: AppPaths
	let preferences: LauncherPreferencesStore
	let log: LauncherLog
	let artworkCache: ArtworkCache
	let launcherIconManager: LauncherIconManager
	let region: @MainActor () -> GameRegion
	let usesDynamicTheme: @MainActor () -> Bool

	var heroArtwork: NSImage? {
		didSet { updateThemeColor() }
	}
	var officialLogo: NSImage?
	private(set) var hasCustomAppIcon = false
	private(set) var hasCustomGameIcon = false
	var dynamicThemeHue: Double?
	var accentColor: Color = LauncherVisuals.cyan
	var hudTintColor: Color = LauncherVisuals.hudGlassTint
	private(set) var activeThemeCacheKey: String?
	/// Increments only when the persisted custom artwork changes. Branding refreshes use this
	/// generation to reject an official image that was already in flight when the user chose a
	/// custom image.
	private(set) var customArtworkGeneration: UInt64 = 0
	private(set) var hasPersistedCustomArtwork = false
	let dataLoader: DataLoader
	let dataStager: DataStager
	let accentExtractor: AccentExtractor
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
		accentExtractor: AccentExtractor? = nil
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
		self.accentExtractor = accentExtractor ?? WallpaperColorExtractor.extractAccent
	}

	static func officialThemeCacheKey(for region: GameRegion, artworkCacheKey: String) -> String {
		"official.\(region.rawValue).\(artworkCacheKey)"
	}

	func setHeroArtwork(_ image: NSImage?, themeCacheKey: String?) {
		guard heroArtwork == nil || activeThemeCacheKey != themeCacheKey else { return }
		activeThemeCacheKey = themeCacheKey
		heroArtwork = image
	}
}
