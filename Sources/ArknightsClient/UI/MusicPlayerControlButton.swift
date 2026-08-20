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
		Button(title, systemImage: systemImage, action: action)
			.labelStyle(.iconOnly)
			.font(.system(size: isProminent ? 16 : 13, weight: .semibold))
			.foregroundStyle(isProminent ? accentTextColor : Color.primary)
			.frame(width: isProminent ? 38 : 34, height: isProminent ? 38 : 34)
			.background(
				isProminent ? accentColor : Color.white.opacity(0.07),
				in: Circle()
			)
			.overlay {
				if !isProminent {
					Circle().strokeBorder(Color.white.opacity(0.08))
				}
			}
			.contentShape(Circle())
			.buttonStyle(.plain)
			.disabled(isDisabled)
			.opacity(isDisabled ? 0.38 : 1)
	}
}
