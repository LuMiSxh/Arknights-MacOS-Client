// SPDX-License-Identifier: MPL-2.0

import SwiftUI

package struct ThemedTextField: View {
	let title: String
	let prompt: String
	@Binding package var text: String
	var systemImage: String?
	package let accentColor: Color

	@FocusState private var isFocused: Bool

	package init(
		_ title: String,
		prompt: String,
		text: Binding<String>,
		systemImage: String? = nil,
		accentColor: Color
	) {
		self.title = title
		self.prompt = prompt
		_text = text
		self.systemImage = systemImage
		self.accentColor = accentColor
	}

	package var body: some View {
		HStack(spacing: 7) {
			if let systemImage {
				Image(systemName: systemImage)
					.font(.caption)
					.adaptiveTintForeground(isFocused ? accentColor : .secondary)
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
			tint: accentColor,
			in: Capsule()
		)
		.contentShape(Capsule())
		.keyboardFocusIndicator(isFocused: isFocused, in: Capsule())
	}
}
