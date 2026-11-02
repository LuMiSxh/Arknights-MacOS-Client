// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Resolved colors for one presentation root: a smoked sheet, neutral surfaces, and HSB accent
/// roles. Apply `.launcherTheme(accent:)` at the root; views read `\.launcherTheme`.
package struct LauncherTheme: Equatable, Sendable {
	package let scrim: Color
	package let sheetTint: Color
	package let modalTint: Color
	package let modalDim: Color
	package let hairline: Color
	/// Modal edge, a little brighter than `hairline` so the card separates from the dimmed sheet.
	package let dialogHairline: Color
	package let groupFill: Color
	package let rowDivider: Color
	package let footerFill: Color
	/// Quiet filled neutral for secondary controls.
	package let controlFill: Color
	package let controlStroke: Color
	package let hoverTint: Color
	package let trackFill: Color
	package let trackStroke: Color
	/// Neutral row selection behind the accent tick.
	package let neutralFill: Color
	package let chipFill: Color
	package let fieldFill: Color

	package let textPrimary: Color
	package let textSecondary: Color
	package let textTertiary: Color

	/// Solid fill for primary controls, the segment thumb and toggles.
	package let accentFill: Color
	/// Text and icons on surfaces.
	package let accentInk: Color
	/// Text on `accentFill`. Always dark, so it stays readable on the light fill.
	package let onAccent: Color
	package let accentGlassTint: Color
	package let accentGlassStroke: Color
	/// Footer pill fill. Light mode uses a frosted white so dark accent ink stays readable on it.
	package let footerGlassTint: Color

	/// Solid fill for destructive controls.
	package let danger: Color
	/// Label on a danger button: near-white pink in dark mode, so it stays readable on the red glass.
	package let dangerInk: Color
	package let dangerGlassTint: Color
	package let dangerGlassStroke: Color

	/// Used only when no artwork accent is available: dark, active, and the cyan accent.
	package static let fallback = LauncherTheme(
		accent: LauncherVisuals.cyan, colorScheme: .dark, isActive: true,
		increasedContrast: false, reduceTransparency: false)

	/// Chromatic glass: a faint tint under the label and a matching stroke.
	private enum Glass {
		static let tintOpacity = 0.14
		static let strokeOpacity = 0.40
	}

	/// Danger hue: 350 degrees, in turns. Matches `LauncherVisuals.danger`, which is red.
	private static let dangerHue = 350.0 / 360

	init(
		accent: Color, colorScheme: ColorScheme, isActive: Bool, increasedContrast: Bool,
		reduceTransparency: Bool
	) {
		let isDark = colorScheme == .dark
		// Increased contrast raises the neutral edges by about 1.5x.
		let edge = increasedContrast ? 1.5 : 1.0
		let (hue, saturation, brightness) = Self.hsb(of: accent)
		// Inactive windows keep each role's brightness and drop its saturation, so the window
		// reads as graphite.
		func tone(hue: Double, saturation: Double, brightness: Double) -> Color {
			Color(hue: hue, saturation: isActive ? saturation : 0, brightness: brightness)
		}
		func ink(_ dark: Double, _ light: Double) -> Color {
			isDark ? Color.white.opacity(dark) : Color.black.opacity(light)
		}

		let primaryText = isDark ? Color.white.opacity(0.92) : Self.hex(0x16171A)
		let sheetBase = isDark ? Self.hex(0x131417) : Self.hex(0xFAFAFB)
		let secondaryOpacity =
			increasedContrast ? (isDark ? 0.78 : 0.82) : (isDark ? 0.62 : 0.68)
		let tertiaryOpacity =
			increasedContrast ? (isDark ? 0.62 : 0.68) : (isDark ? 0.46 : 0.56)
		let fill =
			isActive ? accent : tone(hue: hue, saturation: saturation, brightness: brightness)
		let danger = tone(hue: Self.dangerHue, saturation: 0.72, brightness: isDark ? 0.92 : 0.72)

		scrim = Color.black.opacity(isDark ? 0.40 : 0.16)
		// Reduced transparency makes the sheet and modal opaque.
		sheetTint = sheetBase.opacity(reduceTransparency ? 1 : (isDark ? 0.90 : 0.94))
		modalTint = sheetBase.opacity(reduceTransparency ? 1 : 0.94)
		modalDim = Color.black.opacity(isDark ? 0.40 : 0.20)
		hairline = ink(0.08 * edge, 0.08 * edge)
		dialogHairline = ink(0.10 * edge, 0.08 * edge)
		groupFill = isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.88)
		rowDivider = ink(0.06, 0.06)
		footerFill = Color.black.opacity(isDark ? 0.16 : 0.03)
		controlFill = ink(0.08, 0.05)
		controlStroke = ink(0.10 * edge, 0.08 * edge)
		hoverTint = ink(0.04, 0.04)
		trackFill = ink(0.06, 0.05)
		trackStroke = ink(0.08 * edge, 0.06 * edge)
		neutralFill = ink(0.08, 0.06)
		chipFill = ink(0.10, 0.06)
		fieldFill = ink(0.06, 0.04)

		textPrimary = primaryText
		textSecondary = primaryText.opacity(secondaryOpacity)
		textTertiary = primaryText.opacity(tertiaryOpacity)

		accentFill = fill
		accentInk =
			isDark
			? fill
			: tone(
				hue: hue, saturation: saturation,
				brightness: Self.lightInkBrightness(
					hue: hue, saturation: saturation, from: brightness))
		onAccent = tone(hue: hue, saturation: 0.30, brightness: 0.15)
		accentGlassTint = fill.opacity(Glass.tintOpacity)
		accentGlassStroke = fill.opacity(Glass.strokeOpacity)
		footerGlassTint = isDark ? fill.opacity(Glass.tintOpacity) : Color.white.opacity(0.80)

		self.danger = danger
		dangerInk =
			isDark ? tone(hue: Self.dangerHue, saturation: 0.22, brightness: 1) : danger
		// Red reads darker than the accents on the glass backplate, so it needs a stronger tint.
		dangerGlassTint = danger.opacity(isDark ? 0.36 : 0.40)
		dangerGlassStroke = danger.opacity(Glass.strokeOpacity)
	}

	private static func hsb(
		of color: Color
	) -> (
		hue: Double, saturation: Double, brightness: Double
	) {
		let resolved = color.resolve(in: EnvironmentValues())
		// `Color.Resolved` reports linear light, so encode each channel before reading HSB.
		let red = encodedSRGB(Double(resolved.linearRed))
		let green = encodedSRGB(Double(resolved.linearGreen))
		let blue = encodedSRGB(Double(resolved.linearBlue))
		let maximum = max(red, green, blue)
		let delta = maximum - min(red, green, blue)
		let saturation = maximum == 0 ? 0 : delta / maximum
		var hue = 0.0
		if delta > 0 {
			// Each sector spans a sixth of the wheel; `hue` is in turns.
			if maximum == red {
				hue = ((green - blue) / delta / 6 + 1).truncatingRemainder(dividingBy: 1)
			} else if maximum == green {
				hue = ((blue - red) / delta + 2) / 6
			} else {
				hue = ((red - green) / delta + 4) / 6
			}
		}
		return (hue, saturation, maximum)
	}

	/// Darkens the accent only as far as needed for 4.5:1 text contrast on the light sheet, so
	/// blues stay vivid while yellows darken more.
	private static func lightInkBrightness(
		hue: Double, saturation: Double, from start: Double
	)
		-> Double
	{
		let sheetLuminance = 0.955
		var brightness = start
		while brightness > 0.3 {
			let resolved = Color(hue: hue, saturation: saturation, brightness: brightness)
				.resolve(in: EnvironmentValues())
			let luminance =
				0.2126 * Double(resolved.linearRed) + 0.7152 * Double(resolved.linearGreen)
				+ 0.0722 * Double(resolved.linearBlue)
			if (sheetLuminance + 0.05) / (luminance + 0.05) >= 4.5 { break }
			brightness -= 0.03
		}
		return brightness
	}

	/// Encodes one linear-light channel as sRGB.
	private static func encodedSRGB(_ linear: Double) -> Double {
		let clamped = min(max(linear, 0), 1)
		return clamped <= 0.0031308 ? 12.92 * clamped : 1.055 * pow(clamped, 1 / 2.4) - 0.055
	}

	private static func hex(_ value: UInt32) -> Color {
		Color(
			red: Double((value >> 16) & 0xFF) / 255,
			green: Double((value >> 8) & 0xFF) / 255,
			blue: Double(value & 0xFF) / 255)
	}
}

extension EnvironmentValues {
	@Entry package var launcherTheme = LauncherTheme.fallback
}

extension View {
	/// Injects the launcher theme for this presentation root, resolved from the environment.
	package func launcherTheme(accent: Color) -> some View {
		modifier(LauncherThemeModifier(accent: accent))
	}
}

private struct LauncherThemeModifier: ViewModifier {
	let accent: Color
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.appearsActive) private var appearsActive
	@Environment(\.colorSchemeContrast) private var colorSchemeContrast
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency

	func body(content: Content) -> some View {
		content.environment(
			\.launcherTheme,
			LauncherTheme(
				accent: accent, colorScheme: colorScheme, isActive: appearsActive,
				increasedContrast: colorSchemeContrast == .increased,
				reduceTransparency: reduceTransparency))
	}
}
