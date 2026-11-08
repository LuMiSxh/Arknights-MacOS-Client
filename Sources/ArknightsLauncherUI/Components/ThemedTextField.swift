// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct ThemedTextField: View {
	let title: String
	let prompt: String?
	@Binding var text: String
	var systemImage: String?
	var leadingText: String?

	@Environment(\.launcherTheme) private var theme
	@Environment(\.isEnabled) private var isEnabled
	@FocusState private var isFocused: Bool

	init(
		_ title: String,
		prompt: String? = nil,
		text: Binding<String>,
		systemImage: String? = nil,
		leadingText: String? = nil
	) {
		self.title = title
		self.prompt = prompt
		_text = text
		self.systemImage = systemImage
		self.leadingText = leadingText
	}

	var body: some View {
		HStack(spacing: LauncherTokens.Spacing.control) {
			if let leadingText {
				Text(leadingText)
					.font(.callout.weight(.medium))
					.foregroundStyle(theme.accentInk)
					.accessibilityHidden(true)
			} else if let systemImage {
				Image(systemName: systemImage)
					.font(.caption)
					.foregroundStyle(theme.accentInk)
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
