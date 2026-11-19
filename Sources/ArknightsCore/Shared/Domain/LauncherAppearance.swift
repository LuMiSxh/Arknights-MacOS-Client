// SPDX-License-Identifier: MPL-2.0

package enum LauncherAppearance: String, CaseIterable, Sendable, Identifiable {
	case system
	case light
	case dark

	package var id: String { rawValue }
}

/// Tone of a Home surface: the control pills and settings button, or the top-left branding.
package enum HomeTheme: String, CaseIterable, Sendable, Identifiable {
	/// Light when the artwork behind the controls is bright, otherwise dark.
	case automatic
	case dark
	case light

	package var id: String { rawValue }
}
