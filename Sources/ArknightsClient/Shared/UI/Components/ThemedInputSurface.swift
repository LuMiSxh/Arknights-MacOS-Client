// SPDX-License-Identifier: MPL-2.0

import SwiftUI

private struct ThemedInputSurfaceModifier: ViewModifier {
	let accentColor: Color
	let isFocused: Bool

	@ViewBuilder
	func body(content: Content) -> some View {
		if #available(macOS 26, *) {
			content
				.glassEffect(
					.regular.tint(accentColor.opacity(isFocused ? 0.16 : 0.08)),
					in: .rect(cornerRadius: 10)
				)
				.overlay { focusBorder }
				.contentShape(inputShape)
		} else {
			content
				.background(accentColor.opacity(isFocused ? 0.12 : 0.06), in: inputShape)
				.background(.ultraThinMaterial, in: inputShape)
				.overlay { focusBorder }
				.contentShape(inputShape)
		}
	}

	private var inputShape: RoundedRectangle {
		RoundedRectangle(cornerRadius: 10)
	}

	private var focusBorder: some View {
		inputShape
			.strokeBorder(
				isFocused ? accentColor.opacity(0.72) : LauncherVisuals.controlTint.opacity(0.16),
				lineWidth: isFocused ? 1.5 : 1
			)
			.allowsHitTesting(false)
	}
}

extension View {
	/// Shared focused surface for editable fields on Liquid Glass and Material systems.
	func themedInputSurface(accentColor: Color, isFocused: Bool) -> some View {
		modifier(ThemedInputSurfaceModifier(accentColor: accentColor, isFocused: isFocused))
	}
}
