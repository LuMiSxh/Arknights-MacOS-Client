// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Shared launcher modal composition with a branded header and floating action bar.
struct ThemedModalView<Content: View, Actions: View>: View {
	let title: String
	let accentColor: Color
	let hudTintColor: Color
	let width: CGFloat
	let height: CGFloat
	let minimumWidth: CGFloat
	let minimumHeight: CGFloat
	@ViewBuilder let content: Content
	@ViewBuilder let actions: Actions
	@Environment(\.launcherWindowSize) private var launcherWindowSize

	init(
		title: String,
		accentColor: Color,
		hudTintColor: Color,
		width: CGFloat,
		height: CGFloat,
		minimumWidth: CGFloat = 480,
		minimumHeight: CGFloat = 320,
		@ViewBuilder content: () -> Content,
		@ViewBuilder actions: () -> Actions
	) {
		self.title = title
		self.accentColor = accentColor
		self.hudTintColor = hudTintColor
		self.width = width
		self.height = height
		self.minimumWidth = minimumWidth
		self.minimumHeight = minimumHeight
		self.content = content()
		self.actions = actions()
	}

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
		.frame(width: modalSize.width, height: modalSize.height)
		.background {
			ZStack {
				LauncherVisuals.modalBackground
				hudTintColor
			}
		}
		.preferredColorScheme(.dark)
	}

	private var modalSize: CGSize {
		guard let launcherWindowSize else {
			return CGSize(width: width, height: height)
		}
		let margin: CGFloat = 30
		return CGSize(
			width: clamped(
				width,
				minimum: minimumWidth,
				available: launcherWindowSize.width - (margin * 2)
			),
			height: clamped(
				height,
				minimum: minimumHeight,
				available: launcherWindowSize.height - (margin * 2)
			)
		)
	}

	private func clamped(
		_ preferred: CGFloat,
		minimum: CGFloat,
		available: CGFloat
	) -> CGFloat {
		min(max(preferred, minimum), max(0, available))
	}
}
