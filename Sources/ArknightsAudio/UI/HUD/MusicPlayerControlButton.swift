// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct MusicPlayerControlButton: View {
	let title: String
	let systemImage: String
	package let accentColor: Color
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
							? LauncherVisuals.Typography.hudProminentGlyph
							: LauncherVisuals.Typography.hudControlGlyph
					)
					.adaptiveControlForeground(
						isProminent ? accentColor : LauncherVisuals.controlTint,
						disabledTint: LauncherVisuals.disabled,
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
			tint: isProminent ? accentColor : LauncherVisuals.controlTint,
			isDisabled: isDisabled,
			in: Circle()
		)
	}
}
