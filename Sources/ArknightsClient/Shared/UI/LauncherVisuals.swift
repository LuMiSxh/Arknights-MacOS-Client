// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Shared semantic colors for launcher chrome and controls, independent of any one screen.
enum LauncherVisuals {
	/// Fallback accent used only when artwork cannot provide a dynamic theme color.
	static let cyan = Color(red: 0.094, green: 0.82, blue: 1)
	static let controlTint = Color(red: 0.72, green: 0.74, blue: 0.77)
	/// A quieter neutral for secondary controls and macOS 27's high-contrast borders.
	static let macOS27NeutralControlTint = Color(red: 0.58, green: 0.61, blue: 0.65)
	static let hairline = Color.white.opacity(0.12)
	static let danger = Color(red: 0.69, green: 0.141, blue: 0.231)
	/// Bright semantic foreground for destructive actions; `danger` remains a dark surface tint.
	static let dangerForeground = Color(red: 0.98, green: 0.42, blue: 0.48)
	static let warning = Color(red: 0.91, green: 0.61, blue: 0.21)
	static let success = Color(red: 0.28, green: 0.78, blue: 0.55)
	static let disabled = Color.white.opacity(0.42)
	static let hudGlassTint = Color.black.opacity(0.52)
	static let modalBackground = Color(red: 0.07, green: 0.07, blue: 0.08)
	static let navigationRailBackground = Color.black.opacity(0.28)
	static let panelBorder = Color.white.opacity(0.08)
	static let navigationHoverFill = Color.white.opacity(0.06)

	static func selectedNavigationFill(for accent: Color) -> Color {
		accent.opacity(0.13)
	}

	static func selectedNavigationMarker(for accent: Color) -> Color {
		accent
	}

	static let modalCornerRadius = Radius.modal

	enum Spacing {
		static let hairline: CGFloat = 1
		static let compact: CGFloat = 4
		static let tight: CGFloat = 6
		static let control: CGFloat = 8
		static let content: CGFloat = 12
		static let panel: CGFloat = 16
		static let section: CGFloat = 20
		static let page: CGFloat = 26
	}

	enum Radius {
		static let control: CGFloat = 10
		static let row: CGFloat = 10
		static let panel: CGFloat = 16
		static let hudPill: CGFloat = 22
		static let modal: CGFloat = 24
	}

	enum Control {
		static let borderWidth: CGFloat = 1
		static let focusWidth: CGFloat = 2
		static let standardHorizontalPadding: CGFloat = 12
		static let standardVerticalPadding: CGFloat = 6
		static let compactHorizontalPadding: CGFloat = 10
		static let compactVerticalPadding: CGFloat = 5
		static let hudHorizontalPadding: CGFloat = 11
		static let hudVerticalPadding: CGFloat = 6
		static let enabledNeutralSurfaceOpacity = 0.07
		static let disabledNeutralSurfaceOpacity = 0.025
		static let enabledNeutralBorderOpacity = 0.24
		static let disabledNeutralBorderOpacity = 0.10
		static let enabledChromaticSurfaceOpacity = 0.14
		static let disabledChromaticSurfaceOpacity = 0.035
		static let enabledChromaticBorderOpacity = 0.40
		static let disabledChromaticBorderOpacity = 0.14
		static let hudBorderOpacity = 0.65
		static let hudHoverSurfaceOpacity = 0.06
		static let hudDisabledSurfaceOpacity = 0.68
		static let hudDisabledBorderOpacity = 0.20
		static let opaqueNeutralSurface = Color(red: 0.13, green: 0.14, blue: 0.16)
		static let opaqueDisabledSurface = Color(red: 0.094, green: 0.098, blue: 0.114)
		static let iconButtonSize: CGFloat = 36
		static let iconButtonGlyphSize: CGFloat = 17
	}

	enum Motion {
		static let control = 0.12
		static let selection = 0.16
		static let page = 0.22
		static let progressSweepFadeIn = 0.12
		static let progressSweepTravel = 1.40
		static let progressSweepFadeOut = 0.25
		static let progressSweepPause = 0.55
	}

	/// Raises the contrast of a chromatic foreground while retaining its hue. macOS 27's
	/// Liquid Glass can blend a tint into the surface until the original accent is too close
	/// to the fill, so controls use this only for their foreground and keep the raw tint on
	/// their surface and border.
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
