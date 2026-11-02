// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct LauncherReadabilityField: View {
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.colorScheme) private var colorScheme

	/// The scrim belongs to the top-left branding, so it fades out with the branding setting.
	let showsBranding: Bool

	var body: some View {
		// Both scrims stay in the tree so a scheme change cross-fades. Gradient colors do not
		// animate on their own.
		ZStack {
			scrim([.black, .black.opacity(0.68), .black.opacity(0.2), .clear])
				.opacity(isLightScheme ? 0 : 1)
			scrim([.white, .white.opacity(0.68), .white.opacity(0.2), .clear])
				.opacity(isLightScheme ? 1 : 0)
		}
		.animation(
			LauncherMotion.animation(.state, reduceMotion: reduceMotion), value: isLightScheme
		)
		.frame(width: 680, height: 392, alignment: .topLeading)
		.blur(radius: reduceTransparency ? 0 : 3)
		.opacity(reduceTransparency ? 0.96 : 0.86)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.opacity(showsBranding ? 1 : 0)
		.launcherAnimation(.state, value: showsBranding)
	}

	private var isLightScheme: Bool { colorScheme == .light }

	private func scrim(_ colors: [Color]) -> some View {
		RadialGradient(colors: colors, center: .topLeading, startRadius: 0, endRadius: 450)
	}
}
