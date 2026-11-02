// SPDX-License-Identifier: MPL-2.0

import SwiftUI

package struct ThemedTextField: View {
	let title: String
	let prompt: String?
	@Binding package var text: String
	var systemImage: String?

	@Environment(\.launcherTheme) private var theme
	@Environment(\.isEnabled) private var isEnabled
	@FocusState private var isFocused: Bool

	package init(
		_ title: String,
		prompt: String? = nil,
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
					.foregroundStyle(theme.textSecondary)
					.accessibilityHidden(true)
			}

			TextField(
				"",
				text: $text,
				prompt: prompt.map { Text($0).foregroundStyle(theme.textTertiary) }
			)
			.textFieldStyle(.plain)
			.focusEffectDisabled()
			.focused($isFocused)
			.foregroundStyle(theme.textPrimary)
			.accessibilityLabel(title)
		}
		.font(.callout)
		.launcherFieldSurface(isFocused: isFocused)
		.launcherAnimation(.state, value: isFocused)
		.opacity(isEnabled ? 1 : 0.4)
	}
}
