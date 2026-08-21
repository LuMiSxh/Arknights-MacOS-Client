// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct MusicPlayerControlButton: View {
	let title: String
	let systemImage: String
	let accentColor: Color
	let accentTextColor: Color
	var isProminent = false
	var isDisabled = false
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			controlSurface(
				Label(title, systemImage: systemImage)
					.labelStyle(.iconOnly)
					.font(.system(size: isProminent ? 16 : 13, weight: .semibold))
					.foregroundStyle(
						isProminent ? accentTextColor : LauncherVisuals.controlTint
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
		.buttonStyle(.plain)
		.disabled(isDisabled)
		.opacity(isDisabled ? 0.38 : 1)
	}

	@ViewBuilder
	private func controlSurface(_ content: some View) -> some View {
		if isProminent {
			content.background(accentColor, in: Circle())
		} else {
			content.hudSecondaryControlSurface(in: Circle())
		}
	}
}
