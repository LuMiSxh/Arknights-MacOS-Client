// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

/// Keeps short song titles still and scrolls only when the title exceeds its available width.
struct OverflowingMusicTitle: View {
	let title: String

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var availableWidth: Double = 0
	@State private var textWidth: Double = 0
	@State private var isScrollingReady = false
	@State private var scrollCycleDuration = 1.0

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
					// Mounted only after the delay so each run gets a fresh clock and its final cycle.
					if isScrollingReady {
						ContinuousMotion(cycle: scrollCycleDuration, framesPerSecond: 30) { phase in
							marqueeContent(phase: phase)
						}
					} else {
						marqueeContent(phase: 0)
					}
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
					isScrollingReady = false
					guard textWidth > availableWidth else { return }
					do {
						try await Task.sleep(for: AppConstants.Music.titleScrollDelay)
					} catch {
						return
					}
					scrollCycleDuration = max(
						AppConstants.Music.titleScrollMinimumDuration,
						(textWidth + AppConstants.Music.titleScrollGap)
							/ AppConstants.Music.titleScrollSpeed
					)
					isScrollingReady = true
				}
				.accessibilityElement(children: .ignore)
				.accessibilityLabel(title)
			}
		}
	}

	private func marqueeContent(phase: Double) -> some View {
		HStack(spacing: AppConstants.Music.titleScrollGap) {
			Text(title)
			Text(title)
		}
		.lineLimit(1)
		.fixedSize(horizontal: true, vertical: false)
		.offset(
			x: -(textWidth + AppConstants.Music.titleScrollGap) * phase
		)
	}

	private var animationID: String {
		"\(title)|\(availableWidth.rounded())|\(textWidth.rounded())"
	}
}
