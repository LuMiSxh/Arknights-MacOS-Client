// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Keeps short song titles still and scrolls only when the title exceeds its available width.
struct OverflowingMusicTitle: View {
	let title: String

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var availableWidth: Double = 0
	@State private var textWidth: Double = 0
	@State private var isScrolling = false

	var body: some View {
		if reduceMotion {
			Text(title)
				.lineLimit(1)
				.truncationMode(.tail)
		} else {
			ViewThatFits(in: .horizontal) {
				Text(title)
					.lineLimit(1)
					.fixedSize(horizontal: true, vertical: false)

				GeometryReader { _ in
					HStack(spacing: AppConstants.Music.titleScrollGap) {
						Text(title)
						Text(title)
					}
					.lineLimit(1)
					.fixedSize(horizontal: true, vertical: false)
					.offset(
						x: isScrolling
							? -(textWidth + AppConstants.Music.titleScrollGap)
							: 0
					)
				}
				.background {
					Text(title)
						.lineLimit(1)
						.fixedSize(horizontal: true, vertical: false)
						.hidden()
						.onGeometryChange(for: Double.self) { proxy in
							proxy.size.width
						} action: {
							textWidth = $0
						}
				}
				.onGeometryChange(for: Double.self) { proxy in
					proxy.size.width
				} action: {
					availableWidth = $0
				}
				.clipped()
				.task(id: animationID) {
					isScrolling = false
					guard textWidth > availableWidth else { return }
					try? await Task.sleep(for: AppConstants.Music.titleScrollDelay)
					guard !Task.isCancelled else { return }
					let duration = max(
						AppConstants.Music.titleScrollMinimumDuration,
						(textWidth + AppConstants.Music.titleScrollGap)
							/ AppConstants.Music.titleScrollSpeed
					)
					withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
						isScrolling = true
					}
				}
				.accessibilityElement(children: .ignore)
				.accessibilityLabel(title)
			}
		}
	}

	private var animationID: String {
		"\(title)|\(availableWidth.rounded())|\(textWidth.rounded())"
	}
}
