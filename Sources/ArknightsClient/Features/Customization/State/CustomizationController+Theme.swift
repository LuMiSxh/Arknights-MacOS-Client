// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

extension CustomizationController {
	/// Keeps Dynamic Theme state aligned with the current artwork and the region supplied by the
	/// caller, while rejecting a delayed extraction for artwork that is no longer visible.
	func updateThemeColor() {
		let themeOperationID = UUID()
		self.themeOperationID = themeOperationID
		guard usesDynamicTheme(), let heroArtwork else {
			dynamicThemeHue = nil
			accentColor = LauncherVisuals.cyan
			hudTintColor = LauncherVisuals.hudGlassTint
			updateDynamicAppIcon(hue: nil)
			_ = startOperatorPresetIconRefresh(hue: nil)
			return
		}
		let themeCacheKey = activeThemeCacheKey
		let artworkRegion = region()
		let cachedAccent =
			themeCacheKey
			.flatMap { preferences.dynamicThemeAccent(for: $0) }
			.map {
				ExtractedAccent(
					hue: $0.hue,
					saturation: $0.saturation,
					brightness: $0.brightness
				)
			}
		if let cachedAccent {
			applyThemeAccent(cachedAccent)
		}

		let accentExtractor = self.accentExtractor
		Task { [weak self] in
			guard let self else { return }
			let extracted = await accentExtractor(heroArtwork)
			guard self.themeOperationID == themeOperationID,
				self.heroArtwork === heroArtwork,
				self.activeThemeCacheKey == themeCacheKey,
				self.region() == artworkRegion
			else { return }
			if let themeCacheKey, let extracted {
				self.preferences.setDynamicThemeAccent(
					ThemeAccentSnapshot(
						hue: extracted.hue,
						saturation: extracted.saturation,
						brightness: extracted.brightness
					),
					for: themeCacheKey
				)
			}
			let resolvedAccent = extracted ?? cachedAccent
			self.applyThemeAccent(resolvedAccent)
			self.updateDynamicAppIcon(hue: resolvedAccent?.hue)
			await self.startOperatorPresetIconRefresh(hue: resolvedAccent?.hue).value
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
