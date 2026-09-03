// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Shared semantic colors for launcher chrome and controls, independent of any one screen.
enum LauncherVisuals {
	static let cyan = Color(red: 0.094, green: 0.82, blue: 1)
	static let controlTint = Color(red: 0.72, green: 0.74, blue: 0.77)
	static let hairline = Color.white.opacity(0.12)
	static let danger = Color(red: 0.69, green: 0.141, blue: 0.231)
	static let hudGlassTint = Color.black.opacity(0.52)
	static let modalBackground = Color(red: 0.07, green: 0.07, blue: 0.08)
	static let navigationRailBackground = Color.black.opacity(0.28)
	static let modalCornerRadius: CGFloat = 24
}
