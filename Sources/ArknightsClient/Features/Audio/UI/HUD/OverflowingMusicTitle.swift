// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Keeps short song titles still and scrolls only when the title exceeds its available width.
struct OverflowingMusicTitle: View {
	let title: String

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.decorativeMotionEnabled) private var decorativeMotionEnabled
	@State private var availableWidth: Double = 0
	@State private var textWidth: Double = 0
	@State private var motionClock = DecorativeMotionClock()
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
					if decorativeMotionEnabled && isScrollingReady {
						TimelineView(.animation(minimumInterval: 1 / 30)) { context in
							marqueeContent(
								phase: motionClock.phase(
									at: context.date,
									cycleDuration: scrollCycleDuration
								)
							)
						}
					} else {
						marqueeContent(phase: motionClock.pausedPhase)
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
					motionClock = DecorativeMotionClock()
					guard textWidth > availableWidth else { return }
					try? await Task.sleep(for: AppConstants.Music.titleScrollDelay)
					guard !Task.isCancelled else { return }
					scrollCycleDuration = max(
						AppConstants.Music.titleScrollMinimumDuration,
						(textWidth + AppConstants.Music.titleScrollGap)
							/ AppConstants.Music.titleScrollSpeed
					)
					isScrollingReady = true
					if decorativeMotionEnabled {
						motionClock.begin(at: .now, cycleDuration: scrollCycleDuration)
					} else {
						motionClock.pause(at: .now, cycleDuration: scrollCycleDuration)
					}
				}
				.onAppear {
					if decorativeMotionEnabled {
						motionClock.begin(at: .now, cycleDuration: scrollCycleDuration)
					}
				}
				.onChange(of: decorativeMotionEnabled) { _, isEnabled in
					guard isScrollingReady else { return }
					if isEnabled {
						motionClock.resume(at: .now, cycleDuration: scrollCycleDuration)
					} else {
						motionClock.pause(at: .now, cycleDuration: scrollCycleDuration)
					}
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
