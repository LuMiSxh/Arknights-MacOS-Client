// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Fixed graphite neutrals plus the current theme accent for control on-states.
///
/// The theme hue never reaches surfaces, borders, or secondary controls: tinting them made every
/// artwork collapse into one monochrome cast.
package struct LauncherPalette: Equatable, Sendable {
	/// Hue of the cool graphite ramp. Fixed, so neutrals read the same for every artwork.
	private static let graphiteHue = 0.6

	private let accent: Color

	package static let fallback = LauncherPalette(accent: LauncherVisuals.cyan)

	package init(accent: Color) {
		self.accent = accent
	}

	/// Solid neutral for secondary controls, icons, and keyboard focus rings.
	package var controlTint: Color { graphite(saturation: 0.06, brightness: 0.77) }
	/// On state of toggles, checkboxes, sliders, pickers, and segments.
	package var controlOn: Color { accent }
	package var quietControlTint: Color { graphite(saturation: 0.06, brightness: 0.65) }
	package var hairline: Color { Color.white.opacity(0.12) }
	package var panelBorder: Color { Color.white.opacity(0.08) }
	package var navigationHoverFill: Color { Color.white.opacity(0.06) }
	package var navigationRailBackground: Color { Color.black.opacity(0.28) }
	package var hudGlassTint: Color { Color.black.opacity(0.52) }
	package var modalBackground: Color { graphite(saturation: 0.08, brightness: 0.08) }
	package var galleryPlateBottom: Color { graphite(saturation: 0.08, brightness: 0.07) }
	package var artworkFallback: Color { graphite(saturation: 0.1, brightness: 0.045) }

	private func graphite(saturation: Double, brightness: Double) -> Color {
		Color(hue: Self.graphiteHue, saturation: saturation, brightness: brightness)
	}
}

extension EnvironmentValues {
	@Entry package var launcherPalette = LauncherPalette.fallback
}
