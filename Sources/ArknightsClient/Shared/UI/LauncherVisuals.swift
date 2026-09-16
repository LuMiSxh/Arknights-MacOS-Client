// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Shared semantic colors for launcher chrome and controls, independent of any one screen.
enum LauncherVisuals {
	static let cyan = Color(red: 0.094, green: 0.82, blue: 1)
	static let controlTint = Color(red: 0.72, green: 0.74, blue: 0.77)
	/// A quieter neutral for macOS 27's high-contrast interactive glass borders.
	static let macOS27NeutralControlTint = Color(red: 0.58, green: 0.61, blue: 0.65)
	static let hairline = Color.white.opacity(0.12)
	static let danger = Color(red: 0.69, green: 0.141, blue: 0.231)
	static let hudGlassTint = Color.black.opacity(0.52)
	static let modalBackground = Color(red: 0.07, green: 0.07, blue: 0.08)
	static let navigationRailBackground = Color.black.opacity(0.28)
	static let modalCornerRadius: CGFloat = 24

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
