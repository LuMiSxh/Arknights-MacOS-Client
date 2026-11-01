// SPDX-License-Identifier: MPL-2.0

import SwiftUI

package struct ThemedTextField: View {
	let title: String
	let prompt: String
	@Binding package var text: String
	var systemImage: String?

	@Environment(\.launcherPalette) private var palette
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@FocusState private var isFocused: Bool

	package init(
		_ title: String,
		prompt: String,
		text: Binding<String>,
		systemImage: String? = nil
	) {
		self.title = title
		self.prompt = prompt
		_text = text
		self.systemImage = systemImage
	}

	package var body: some View {
		HStack(spacing: 8) {
			if let systemImage {
				Image(systemName: systemImage)
					.font(.caption)
					.adaptiveTintForeground(palette.controlTint)
					.accessibilityHidden(true)
			}

			TextField(prompt, text: $text)
				.textFieldStyle(.plain)
				.focused($isFocused)
				.accessibilityLabel(title)
		}
		.font(.callout)
		.padding(.horizontal, LauncherVisuals.Control.compactHorizontalPadding)
		.padding(.vertical, LauncherVisuals.Control.compactVerticalPadding + 2)
		.adaptiveControlSurface(
			tint: isFocused ? palette.controlOn : palette.controlTint,
			borderOpacity: isFocused ? 0.62 : nil,
			in: Capsule()
		)
		.contentShape(Capsule())
		.animation(LauncherMotion.animation(.state, reduceMotion: reduceMotion), value: isFocused)
	}
}
