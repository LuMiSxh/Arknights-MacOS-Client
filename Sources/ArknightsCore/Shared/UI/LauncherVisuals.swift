// SPDX-License-Identifier: MPL-2.0

import SwiftUI

package enum LauncherVisuals {
	/// Fallback accent used only when artwork cannot provide a dynamic theme color.
	package static let cyan = Color(red: 0.094, green: 0.82, blue: 1)

	/// Opaque black for surfaces that must fully hide whatever sits behind them.
	package static let opaqueDim = Color.black

	package static let overlayDim = 0.55

	package static func selectedNavigationFill(for accent: Color) -> Color {
		accent.opacity(0.13)
	}

	/// Opacities for control surfaces, borders, and disabled foregrounds.
	package enum Control {
		package static let enabledNeutralSurfaceOpacity = 0.07
		package static let enabledNeutralBorderOpacity = 0.24
		package static let enabledChromaticSurfaceOpacity = 0.14
		package static let enabledChromaticBorderOpacity = 0.40
		static let disabledChromaticBorderOpacity = 0.14
		package static let disabledForegroundOpacity = 0.44
		static let disabledForegroundHighContrastOpacity = 0.52
		static let hudBorderOpacity = 0.16
		static let hudDisabledSurfaceOpacity = 0.68
		package static let hudSurfaceOpacity = 0.52
		static let chromaticHoverOpacity = 0.05
		package static let inactiveSelectionOpacity = 0.45

		package static func disabledForegroundOpacity(for contrast: ColorSchemeContrast) -> Double {
			contrast == .increased
				? disabledForegroundHighContrastOpacity
				: disabledForegroundOpacity
		}
	}

	/// Fixed shades and scrims outside the theme roles.
	package enum Shade {
		/// Dark footer gradient behind floating controls.
		static let footerDarkOpacity = 0.45
		/// Black scrim over artwork while a preset applies.
		package static let loadingScrimOpacity = 0.65
		/// Shadow under preset artwork tiles.
		package static let artworkShadowOpacity = 0.3
	}

	/// Shadow opacities for the shared surface kinds.
	enum Shadow {
		static let modalDarkOpacity = 0.45
		static let modalLightOpacity = 0.14
		static let groupLightOpacity = 0.04
		static let footerDarkOpacity = 0.35
		static let footerLightOpacity = 0.12
	}

	/// Accent halo pulse opacities.
	enum Halo {
		static let restingOpacity = 0.1125
		static let pulseOpacityGain = 0.1375
	}

	/// Indeterminate progress outline opacities.
	enum Progress {
		static let trackRestOpacity = 0.35
		static let trackBreathOpacity = 0.15
		static let glintOpacity = 0.65
	}

	/// Accent focus ring around the focused control.
	static let focusStrokeOpacity = 0.9

	// Raises the contrast of a chromatic foreground while retaining its hue. macOS 27's
	// Liquid Glass can blend a tint into the surface until the original accent is too close
	// to the fill, so controls use this only for their foreground and keep the raw tint on
	// their surface and border.
	static func contrastTint(_ color: Color) -> Color {
		let resolved = color.resolve(in: EnvironmentValues())
		let red = Double(resolved.red)
		let green = Double(resolved.green)
		let blue = Double(resolved.blue)
		let chroma = max(red, green, blue) - min(red, green, blue)
		guard chroma > 0.08 else { return color }

		let whiteMix = 0.28
		return Color(
			.sRGB,
			red: red + (1 - red) * whiteMix,
			green: green + (1 - green) * whiteMix,
			blue: blue + (1 - blue) * whiteMix,
			opacity: 1
		)
	}
}
