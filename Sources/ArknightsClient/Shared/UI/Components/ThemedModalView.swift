// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Shared launcher modal composition with a branded header and floating action bar.
struct ThemedModalView<Content: View, Actions: View>: View {
	let title: String
	let accentColor: Color
	let hudTintColor: Color
	let width: CGFloat
	let height: CGFloat
	@ViewBuilder let content: Content
	@ViewBuilder let actions: Actions

	var body: some View {
		ZStack(alignment: .bottomTrailing) {
			VStack(spacing: 0) {
				VStack(alignment: .leading, spacing: 10) {
					Text(title)
						.font(.title2.bold())
					HStack(spacing: 8) {
						Rectangle().fill(accentColor).frame(width: 72, height: 3)
						Rectangle().fill(LauncherVisuals.hairline)
							.frame(height: 1)
							.frame(maxWidth: .infinity)
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(.horizontal, 24)
				.padding(.top, 22)
				.padding(.bottom, 16)

				ScrollView {
					content
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding(.horizontal, 24)
						.padding(.top, 2)
						.padding(.bottom, 76)
				}
				.contentMargins(.top, 8, for: .scrollIndicators)
				.contentMargins(.bottom, 22, for: .scrollIndicators)
				.scrollIndicators(.automatic)
			}

			FloatingActionFooterFade(height: 72)

			FloatingActionBar(tint: hudTintColor) {
				actions
			}
			.textSelection(.disabled)
			.padding(.trailing, 24)
			.padding(.bottom, 18)
		}
		.frame(width: width, height: height)
		.background {
			ZStack {
				Color(red: 0.07, green: 0.07, blue: 0.08)
				hudTintColor
			}
		}
		.preferredColorScheme(.dark)
	}
}
