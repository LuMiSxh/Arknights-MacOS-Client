// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

extension LauncherViewModel {
	/// Keeps `accentColor`/`hudTintColor` in sync with `usesDynamicTheme` and `heroArtwork`.
	/// Falls back to the fixed Arknights cyan and the static HUD tint when dynamic theming
	/// is off, no artwork is loaded, or extraction finds nothing vibrant enough.
	func updateThemeColor() {
		guard usesDynamicTheme, let heroArtwork else {
			accentColor = SettingsVisuals.cyan
			hudTintColor = SettingsVisuals.hudGlassTint
			return
		}

		Task { [weak self] in
			guard let self else { return }
			let extracted = await WallpaperColorExtractor.extractAccent(from: heroArtwork)
			// The artwork may have changed again while extraction was in flight; only apply
			// a result that still matches the artwork it was sampled from.
			guard self.heroArtwork === heroArtwork else { return }
			self.accentColor = extracted?.accentColor ?? SettingsVisuals.cyan
			self.hudTintColor = extracted?.backgroundTint ?? SettingsVisuals.hudGlassTint
		}
	}
}
