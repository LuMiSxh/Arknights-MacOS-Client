// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Shared native-feeling press feedback for custom launcher action surfaces.
struct ActionPressStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.opacity(configuration.isPressed ? 0.72 : 1)
			.scaleEffect(configuration.isPressed ? 0.98 : 1)
			.animation(.easeOut(duration: 0.12), value: configuration.isPressed)
	}
}
