// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct MusicPlayerControlButton: View {
	@Environment(\.launcherTheme) private var theme
	let title: String
	let systemImage: String
	let accentColor: Color
	var isProminent = false
	var isDisabled = false
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			controlSurface(
				Label(title, systemImage: systemImage)
					.labelStyle(.iconOnly)
					.font(
						isProminent
							? LauncherTokens.Typography.hudProminentGlyph
							: LauncherTokens.Typography.hudControlGlyph
					)
					.adaptiveControlForeground(
						isProminent ? theme.accentInk : theme.textPrimary,
						disabledTint: theme.textTertiary,
						isDisabled: isDisabled
					)
					.frame(
						width: isProminent
							? AppConstants.Music.prominentControlDimension
							: AppConstants.Music.secondaryControlDimension,
						height: isProminent
							? AppConstants.Music.prominentControlDimension
							: AppConstants.Music.secondaryControlDimension
					)
			)
			.contentShape(Circle())
		}
		.buttonStyle(ActionPressStyle())
		.keyboardFocusIndicator(in: Circle())
		.disabled(isDisabled)
		.accessibilityLabel(title)
	}

	@ViewBuilder
	private func controlSurface(_ content: some View) -> some View {
		content.adaptiveControlSurface(
			tint: isProminent ? accentColor : theme.textPrimary,
			isDisabled: isDisabled,
			in: Circle()
		)
	}
}
