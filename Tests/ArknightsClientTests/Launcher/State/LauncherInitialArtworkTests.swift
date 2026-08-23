// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherInitialArtworkTests {
	@Test
	func cachedOfficialArtworkIsVisibleBeforeRefreshAndKeptWhenUnchanged() async throws {
		let root = FileManager.default.temporaryDirectory.appending(
			path: "LauncherInitialArtworkTests.\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		defer { try? FileManager.default.removeItem(at: root) }
		let paths = AppPaths(
			applicationSupportDirectory: root.appending(path: "Support"),
			cachesDirectory: root.appending(path: "Caches"),
			libraryDirectory: root.appending(path: "Library")
		)
		let defaults = try #require(
			UserDefaults(suiteName: "LauncherInitialArtworkTests.\(UUID().uuidString)")
		)
		let preferences = LauncherPreferencesStore(defaults: defaults)
		preferences.setAutomaticGameUpdates(false)
		preferences.setAutomaticLauncherUpdates(false)
		preferences.setAnnouncementsEnabled(false)

		let imageData = try #require(
			Data(
				base64Encoded:
					"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zf9sAAAAASUVORK5CYII="
			)
		)
		let cacheKey = "startup-artwork"
		let branding = LauncherBranding(
			launcherBackgroundImage: URL(string: "https://example.com/artwork.jpg"),
			launcherBackgroundImageCRC64: cacheKey,
			copyrightInformation: nil,
			privacyPolicy: nil,
			userAgreement: nil,
			noticePopOpen: nil,
			noticeContent: nil
		)
		try FileManager.default.createDirectory(
			at: paths.artworkCache,
			withIntermediateDirectories: true
		)
		try imageData.write(to: paths.artworkCache.appending(path: "\(cacheKey).jpg"))
		let cache = ArtworkCache(directory: paths.artworkCache)
		_ = try await cache.imageData(for: branding, region: .global)
		let themeKey = CustomizationController.officialThemeCacheKey(
			for: .global,
			artworkCacheKey: cacheKey
		)
		let accent = ThemeAccentSnapshot(hue: 0.42, saturation: 0.7, brightness: 0.8)
		preferences.setDynamicThemeAccent(accent, for: themeKey)

		let api = BlockingBrandingAPI()
		let model = LauncherViewModel(
			api: api,
			installer: ControllableInstaller(),
			paths: paths,
			preferences: preferences,
			checkIntelTranslation: {
				IntelTranslationCheck(state: .available, diagnostics: "test")
			},
			arguments: []
		)

		let initialArtwork = try #require(model.customization.heroArtwork)
		#expect(model.customization.activeThemeCacheKey == themeKey)
		#expect(model.customization.dynamicThemeHue == accent.hue)

		await api.waitForBrandingRequest()
		await api.resolveBranding(branding)
		await model.waitForStartup()

		#expect(model.customization.heroArtwork === initialArtwork)
	}
}
