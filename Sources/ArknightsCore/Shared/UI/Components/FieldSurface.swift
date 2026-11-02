// SPDX-License-Identifier: MPL-2.0

import SwiftUI

extension View {
	/// The capsule surface for text input. Height, fill, and stroke match `GlassMenuPicker`, so a
	/// field and a select sit side by side. Focus turns the stroke to the accent.
	package func launcherFieldSurface(isFocused: Bool) -> some View {
		modifier(LauncherFieldSurfaceModifier(isFocused: isFocused))
	}
}

private struct LauncherFieldSurfaceModifier: ViewModifier {
	@Environment(\.launcherTheme) private var theme
	let isFocused: Bool

	func body(content: Content) -> some View {
		content
			.padding(.horizontal, LauncherVisuals.Control.standardHorizontalPadding)
			.frame(height: LauncherVisuals.Control.fieldHeight)
			.background { Capsule().fill(theme.controlFill) }
			.overlay {
				Capsule().strokeBorder(
					isFocused ? theme.accentFill : theme.controlStroke,
					lineWidth: LauncherVisuals.Control.borderWidth)
			}
			.contentShape(Capsule())
	}
}
