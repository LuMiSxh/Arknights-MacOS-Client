// SPDX-License-Identifier: MPL-2.0

import SwiftUI

package enum LauncherVisuals {
	/// Fallback accent used only when artwork cannot provide a dynamic theme color.
	package static let cyan = Color(red: 0.094, green: 0.82, blue: 1)
	package static let danger = Color(red: 0.69, green: 0.141, blue: 0.231)
	/// Bright semantic foreground for destructive actions; `danger` remains a dark surface tint.
	package static let dangerForeground = Color(red: 0.98, green: 0.42, blue: 0.48)
	static let dangerForegroundHighContrast = Color(red: 1, green: 0.55, blue: 0.60)
	package static let warning = Color(red: 0.91, green: 0.61, blue: 0.21)
	package static let success = Color(red: 0.28, green: 0.78, blue: 0.55)
	package static let disabled = Color.white.opacity(0.42)
	package static let overlayDim = 0.55

	package static func selectedNavigationFill(for accent: Color) -> Color {
		accent.opacity(0.13)
	}

	static let modalCornerRadius = Radius.modal

	package enum Typography {
		package static let statusTitle = Font.system(size: 14, weight: .medium)
		package static let statusPercent = Font.system(size: 16, weight: .medium)
		package static let completionLabel = Font.system(size: 15, weight: .medium)
		package static let hudControlGlyph = Font.system(size: 13, weight: .medium)
		package static let hudProminentGlyph = Font.system(size: 16, weight: .medium)
		static let menuChevron = Font.system(size: 9, weight: .medium)
		package static let tagGlyph = Font.system(size: 10, weight: .medium)
		package static let fallbackWordmark = Font.system(size: 440, weight: .regular)
		package static let wordmark = Font.system(.title, design: .serif)
	}

	package enum Layout {
		/// Shared by the Settings and Onboarding navigation rails.
		package static let railWidth: CGFloat = 192
	}

	package enum Spacing {
		package static let hairline: CGFloat = 1
		package static let compact: CGFloat = 4
		package static let control: CGFloat = 8
		package static let content: CGFloat = 12
		package static let panel: CGFloat = 16
		package static let section: CGFloat = 20
		package static let page: CGFloat = 24
	}

	package enum Radius {
		package static let control: CGFloat = 10
		package static let panel: CGFloat = 16
		static let hudPill: CGFloat = 22
		package static let modal: CGFloat = 24
	}

	package enum Control {
		package static let borderWidth: CGFloat = 1
		static let focusWidth: CGFloat = 2
		static let standardHorizontalPadding: CGFloat = 12
		static let standardVerticalPadding: CGFloat = 6
		static let compactHorizontalPadding: CGFloat = 8
		static let compactVerticalPadding: CGFloat = 4
		package static let hudHorizontalPadding: CGFloat = 12
		package static let hudVerticalPadding: CGFloat = 6
		package static let enabledNeutralSurfaceOpacity = 0.07
		static let disabledNeutralSurfaceOpacity = 0.025
		package static let enabledNeutralBorderOpacity = 0.24
		static let disabledNeutralBorderOpacity = 0.10
		package static let enabledChromaticSurfaceOpacity = 0.14
		static let disabledChromaticSurfaceOpacity = 0.035
		package static let enabledChromaticBorderOpacity = 0.40
		static let disabledChromaticBorderOpacity = 0.14
		static let semanticBorderOpacity = 0.28
		static let semanticBorderHighContrastOpacity = 0.52
		package static let disabledForegroundOpacity = 0.44
		static let disabledForegroundHighContrastOpacity = 0.52
		static let disabledNeutralForegroundOpacity = 0.36
		static let disabledNeutralForegroundHighContrastOpacity = 0.52
		static let hudBorderOpacity = 0.16
		package static let hudHoverSurfaceOpacity = 0.06
		package static let controlHoverSurfaceOpacity = 0.06
		static let hudDisabledSurfaceOpacity = 0.68
		static let hudDisabledBorderOpacity = 0.20
		static let opaqueNeutralSurface = Color(red: 0.13, green: 0.14, blue: 0.16)
		static let opaqueDisabledSurface = Color(red: 0.094, green: 0.098, blue: 0.114)
		static let iconButtonSize: CGFloat = 36
		static let iconButtonGlyphSize: CGFloat = 17

		package static func disabledForegroundOpacity(for contrast: ColorSchemeContrast) -> Double {
			contrast == .increased
				? disabledForegroundHighContrastOpacity
				: disabledForegroundOpacity
		}

		static func disabledNeutralForegroundOpacity(
			for contrast: ColorSchemeContrast
		)
			-> Double
		{
			contrast == .increased
				? disabledNeutralForegroundHighContrastOpacity
				: disabledNeutralForegroundOpacity
		}
	}

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
