// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import Observation
import SwiftUI

/// Owns launcher artwork, Dynamic Theme, and launcher/game icon customizations.
@MainActor
@Observable
final class CustomizationController {
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
	var dynamicThemeHue: Double?
	var accentColor: Color = LauncherVisuals.cyan
	var hudTintColor: Color = LauncherVisuals.hudGlassTint
	private(set) var activeThemeCacheKey: String?
	/// Increments only when the persisted custom artwork changes. Branding refreshes use this
	/// generation to reject an official image that was already in flight when the user chose a
	/// custom image.
	private(set) var customArtworkGeneration: UInt64 = 0
	var hasPersistedCustomArtwork: Bool {
		FileManager.default.fileExists(atPath: paths.customArtwork.path)
	}

	func customArtworkDidChange() {
		customArtworkGeneration &+= 1
	}

	init(
		lifecycle: LauncherLifecycleStore,
		paths: AppPaths,
		preferences: LauncherPreferencesStore,
		log: LauncherLog? = nil,
		artworkCache: ArtworkCache? = nil,
		launcherIconManager: LauncherIconManager,
		region: @escaping @MainActor () -> GameRegion,
		usesDynamicTheme: @escaping @MainActor () -> Bool
	) {
		self.lifecycle = lifecycle
		self.paths = paths
		self.preferences = preferences
		self.log = log ?? lifecycle.log
		self.artworkCache = artworkCache ?? ArtworkCache(directory: paths.artworkCache)
		self.launcherIconManager = launcherIconManager
		self.region = region
		self.usesDynamicTheme = usesDynamicTheme
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
