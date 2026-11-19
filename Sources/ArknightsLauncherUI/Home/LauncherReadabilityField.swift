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
			scrim(LauncherVisuals.ReadabilityScrim.dark)
				.opacity(isLightScheme ? 0 : 1)
			scrim(LauncherVisuals.ReadabilityScrim.light)
				.opacity(isLightScheme ? 1 : 0)
		}
		.animation(
			LauncherMotion.animation(.state, reduceMotion: reduceMotion), value: isLightScheme
		)
		.frame(
			width: LauncherTokens.Layout.readabilityFieldWidth,
			height: LauncherTokens.Layout.readabilityFieldHeight,
			alignment: .topLeading
		)
		.blur(radius: reduceTransparency ? 0 : LauncherTokens.Layout.readabilityFieldBlurRadius)
		.opacity(
			reduceTransparency
				? LauncherVisuals.ReadabilityScrim.reducedTransparencyOpacity
				: LauncherVisuals.ReadabilityScrim.normalOpacity
		)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.opacity(showsBranding ? 1 : 0)
		.launcherAnimation(.state, value: showsBranding)
	}

	private var isLightScheme: Bool { colorScheme == .light }

	private static let scrimEndRadius: CGFloat = 450

	private func scrim(_ colors: [Color]) -> some View {
		RadialGradient(
			colors: colors, center: .topLeading, startRadius: 0,
			endRadius: Self.scrimEndRadius)
	}
}
