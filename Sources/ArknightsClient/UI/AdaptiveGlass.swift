// SPDX-License-Identifier: MPL-2.0

import SwiftUI

extension View {
	/// Applies Liquid Glass on macOS 26 and newer; on macOS 15–25, layers a translucent
	/// material fill behind the content instead, since `glassEffect` isn't available there.
	@ViewBuilder
	func adaptiveGlassEffect(
		tint: Color? = nil,
		in shape: some Shape = Rectangle()
	) -> some View {
		if #available(macOS 26, *) {
			if let tint {
				self.glassEffect(.regular.tint(tint), in: shape)
			} else {
				self.glassEffect(.regular, in: shape)
			}
		} else {
			if let tint {
				self.background(tint, in: shape)
					.background(.ultraThinMaterial, in: shape)
			} else {
				self.background(.regularMaterial, in: shape)
			}
		}
	}

	/// Applies the Liquid Glass button styles on macOS 26 and newer, falling back to the
	/// native bordered styles on macOS 15–25 where `.glass`/`.glassProminent` don't exist.
	@ViewBuilder
	func adaptiveGlassButton(prominent: Bool = false) -> some View {
		if #available(macOS 26, *) {
			if prominent {
				self.buttonStyle(.glassProminent)
			} else {
				self.buttonStyle(.glass)
			}
		} else {
			if prominent {
				self.buttonStyle(.borderedProminent)
			} else {
				self.buttonStyle(.bordered)
			}
		}
	}
}
