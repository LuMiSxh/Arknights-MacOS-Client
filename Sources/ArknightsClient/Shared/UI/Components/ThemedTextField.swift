// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// A branded single-line input with a visible keyboard-focus state and a Material fallback.
struct ThemedTextField: View {
	let title: String
	let prompt: String
	@Binding var text: String
	var systemImage: String?
	let accentColor: Color

	@FocusState private var isFocused: Bool

	init(
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

	var body: some View {
		HStack(spacing: 7) {
			if let systemImage {
				Image(systemName: systemImage)
					.font(.caption)
					.foregroundStyle(isFocused ? accentColor : .secondary)
					.accessibilityHidden(true)
			}

			TextField(prompt, text: $text)
				.textFieldStyle(.plain)
				.focused($isFocused)
				.accessibilityLabel(title)
		}
		.font(.callout)
		.padding(.horizontal, 10)
		.padding(.vertical, 7)
		.adaptiveGlassEffect(
			tint: accentColor.opacity(isFocused ? 0.16 : 0.08),
			in: RoundedRectangle(cornerRadius: 10)
		)
		.overlay {
			RoundedRectangle(cornerRadius: 10)
				.strokeBorder(
					isFocused
						? accentColor.opacity(0.72) : LauncherVisuals.controlTint.opacity(0.16),
					lineWidth: isFocused ? 1.5 : 1
				)
				.allowsHitTesting(false)
		}
		.contentShape(RoundedRectangle(cornerRadius: 10))
		.focusEffectDisabled(true)
	}
}
