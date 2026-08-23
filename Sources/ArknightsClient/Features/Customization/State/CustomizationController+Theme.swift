// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

extension CustomizationController {
	/// Keeps Dynamic Theme state aligned with the current artwork and the region supplied by the
	/// caller, while rejecting a delayed extraction for artwork that is no longer visible.
	func updateThemeColor() {
		guard usesDynamicTheme(), let heroArtwork else {
			dynamicThemeHue = nil
			accentColor = LauncherVisuals.cyan
			hudTintColor = LauncherVisuals.hudGlassTint
			updateDynamicAppIcon(hue: nil)
			Task { [weak self] in await self?.refreshOperatorPresetIconsForTheme(hue: nil) }
			return
		}
		let themeCacheKey = activeThemeCacheKey
		let artworkRegion = region()
		if let themeCacheKey, let cached = preferences.dynamicThemeAccent(for: themeCacheKey) {
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
			guard self.heroArtwork === heroArtwork,
				self.activeThemeCacheKey == themeCacheKey,
				self.region() == artworkRegion
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

	func updateDynamicAppIcon(hue: Double?) {
		guard !hasCustomAppIcon else { return }
		if usesDynamicTheme(), let hue {
			if let tinted = AppIconRenderer.tintedDefaultIcon(for: hue) {
				applyDynamicLauncherIcon(tinted)
			}
		} else {
			resetDynamicLauncherIcon()
		}
	}

	private func applyThemeAccent(_ extracted: ExtractedAccent?) {
		dynamicThemeHue = extracted?.hue
		accentColor = extracted?.accentColor ?? LauncherVisuals.cyan
		hudTintColor = extracted?.backgroundTint ?? LauncherVisuals.hudGlassTint
	}

	private func applyDynamicLauncherIcon(_ image: NSImage) {
		guard !launcherIconManager.apply(image) else { return }
		Task { [log] in await log.error("Failed to persist the Dynamic Theme launcher icon") }
	}

	private func resetDynamicLauncherIcon() {
		guard !launcherIconManager.reset() else { return }
		Task { [log] in await log.error("Failed to restore the bundled launcher icon") }
	}
}
