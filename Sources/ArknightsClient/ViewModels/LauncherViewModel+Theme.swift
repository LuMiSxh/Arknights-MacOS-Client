// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

extension LauncherViewModel {
	static func officialThemeCacheKey(for region: GameRegion, artworkCacheKey: String) -> String {
		"official.\(region.rawValue).\(artworkCacheKey)"
	}

	func setHeroArtwork(_ image: NSImage?, themeCacheKey: String?) {
		guard heroArtwork == nil || activeThemeCacheKey != themeCacheKey else { return }
		activeThemeCacheKey = themeCacheKey
		heroArtwork = image
	}

	/// Keeps `accentColor`/`hudTintColor` in sync with `usesDynamicTheme` and `heroArtwork`.
	/// Falls back to the fixed Arknights cyan and the static HUD tint when dynamic theming
	/// is off, no artwork is loaded, or extraction finds nothing vibrant enough.
	func updateThemeColor() {
		guard usesDynamicTheme, let heroArtwork else {
			dynamicThemeHue = nil
			accentColor = SettingsVisuals.cyan
			accentTextColor = Color.black.opacity(0.92)
			hudTintColor = SettingsVisuals.hudGlassTint
			updateDynamicAppIcon(hue: nil)
			Task { [weak self] in await self?.refreshOperatorPresetIconsForTheme(hue: nil) }
			return
		}
		let themeCacheKey = activeThemeCacheKey
		let artworkRegion = region
		if let themeCacheKey,
			let cached = preferences.dynamicThemeAccent(for: themeCacheKey)
		{
			applyThemeAccent(
				ExtractedAccent(
					hue: cached.hue,
					saturation: cached.saturation,
					brightness: cached.brightness
				)
			)
		}

		Task { [weak self] in
			guard let self else { return }
			let extracted = await WallpaperColorExtractor.extractAccent(from: heroArtwork)
			// The artwork may have changed again while extraction was in flight; only apply
			// a result that still matches the artwork it was sampled from.
			guard self.heroArtwork === heroArtwork,
				self.activeThemeCacheKey == themeCacheKey,
				self.region == artworkRegion
			else { return }
			if let themeCacheKey {
				self.preferences.setDynamicThemeAccent(
					extracted.map {
						ThemeAccentSnapshot(
							hue: $0.hue,
							saturation: $0.saturation,
							brightness: $0.brightness
						)
					},
					for: themeCacheKey
				)
			}
			self.applyThemeAccent(extracted)
			self.updateDynamicAppIcon(hue: extracted?.hue)
			await self.refreshOperatorPresetIconsForTheme(hue: extracted?.hue)
		}
	}

	private func applyThemeAccent(_ extracted: ExtractedAccent?) {
		dynamicThemeHue = extracted?.hue
		accentColor = extracted?.accentColor ?? SettingsVisuals.cyan
		accentTextColor = extracted?.accentTextColor ?? Color.black.opacity(0.92)
		hudTintColor = extracted?.backgroundTint ?? SettingsVisuals.hudGlassTint
	}

	func updateDynamicAppIcon(hue: Double?) {
		guard !hasCustomAppIcon else { return }

		if usesDynamicTheme, let hue {
			if let tinted = AppIconRenderer.tintedDefaultIcon(for: hue) {
				NSApp?.applicationIconImage = tinted
			}
		} else {
			NSApp?.applicationIconImage = nil
		}
	}
}
