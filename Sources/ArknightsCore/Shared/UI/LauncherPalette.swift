// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Fixed graphite neutrals for secondary controls and artwork fallbacks.
///
/// The theme hue never reaches surfaces, borders, or secondary controls: tinting them made every
/// artwork collapse into one monochrome cast.
package struct LauncherPalette: Equatable, Sendable {
	/// Hue of the cool graphite ramp. Fixed, so neutrals read the same for every artwork.
	private static let graphiteHue = 0.6

	/// Solid neutral for secondary controls, icons, and keyboard focus rings.
	package var controlTint: Color { graphite(saturation: 0.06, brightness: 0.77) }

	package var quietControlTint: Color { graphite(saturation: 0.06, brightness: 0.65) }
	package var hairline: Color { Color.white.opacity(0.12) }

	package var hudGlassTint: Color { Color.black.opacity(0.52) }

	package var artworkFallback: Color { graphite(saturation: 0.1, brightness: 0.045) }

	private func graphite(saturation: Double, brightness: Double) -> Color {
		Color(hue: Self.graphiteHue, saturation: saturation, brightness: brightness)
	}
}

extension EnvironmentValues {
	@Entry package var launcherPalette = LauncherPalette()
}
