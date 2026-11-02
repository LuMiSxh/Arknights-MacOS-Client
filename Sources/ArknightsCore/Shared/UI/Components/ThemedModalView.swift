// SPDX-License-Identifier: MPL-2.0

import SwiftUI

package struct ThemedModalView<Content: View, Actions: View>: View {
	let title: String
	// Kept for existing call sites; the theme supplies the color.
	let hudTintColor: Color
	package let width: CGFloat
	package let height: CGFloat
	let minimumWidth: CGFloat
	let minimumHeight: CGFloat
	@ViewBuilder package let content: Content
	@ViewBuilder package let actions: Actions
	@Environment(\.launcherWindowSize) private var launcherWindowSize
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var hasEntered = false

	package init(
		title: String,
		hudTintColor: Color,
		width: CGFloat,
		height: CGFloat,
		minimumWidth: CGFloat = 480,
		minimumHeight: CGFloat = 320,
		@ViewBuilder content: () -> Content,
		@ViewBuilder actions: () -> Actions
	) {
		self.title = title
		self.hudTintColor = hudTintColor
		self.width = width
		self.height = height
		self.minimumWidth = minimumWidth
		self.minimumHeight = minimumHeight
		self.content = content()
		self.actions = actions()
	}

	@Environment(\.launcherTheme) private var theme

	package var body: some View {
		VStack(spacing: 0) {
			VStack(alignment: .leading, spacing: 8) {
				Text(title)
					.font(.title2.weight(.medium))
				HStack(spacing: 8) {
					Rectangle()
						.fill(theme.accentFill)
						.frame(width: hasEntered || reduceMotion ? 48 : 0, height: 2)
					Rectangle().fill(theme.hairline)
						.frame(height: 1)
						.frame(maxWidth: .infinity)
						.scaleEffect(x: hasEntered || reduceMotion ? 1 : 0, anchor: .leading)
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(.horizontal, 24)
			.padding(.top, 24)
			.padding(.bottom, 16)

			ScrollView {
				content
					.frame(maxWidth: .infinity, alignment: .leading)
					.padding(.horizontal, 24)
					.padding(.top, 4)
					.padding(.bottom, 20)
			}
			.scrollIndicators(.automatic)
		}
		.safeAreaInset(edge: .bottom, spacing: 0) {
			FloatingActionBar(tint: hudTintColor) {
				actions
			}
			.textSelection(.disabled)
			.padding(.top, 16)
			.padding(.trailing, 24)
			.padding(.bottom, 16)
			.frame(maxWidth: .infinity, alignment: .trailing)
			.background {
				FloatingActionFooterFade()
			}
		}
		.frame(width: modalSize.width, height: modalSize.height)
		.launcherSurface(.modal)
		.background {
			// Dims the window behind the card; the card leaves with it.
			theme.modalDim.ignoresSafeArea()
		}
		.modifier(ModalEntrance(hasEntered: hasEntered, reduceMotion: reduceMotion))
		.transition(
			reduceMotion
				? .opacity
				: .asymmetric(
					insertion: .identity,
					removal: .opacity.combined(with: .scale(scale: 0.98))
						.animation(LauncherMotion.Role.dismiss.animation()))
		)
		.onAppear {
			let entrance = LauncherMotion.animation(.present, reduceMotion: reduceMotion)
			withAnimation(entrance?.delay(LauncherMotion.modalEntranceDelay)) {
				hasEntered = true
			}
		}
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

// Lets modal content settle in after the native sheet lifecycle has placed the window.
private struct ModalEntrance: ViewModifier {
	let hasEntered: Bool
	let reduceMotion: Bool

	func body(content: Content) -> some View {
		let entered = hasEntered || reduceMotion
		content
			.opacity(entered ? 1 : 0)
			.scaleEffect(entered ? 1 : 0.97)
	}
}
