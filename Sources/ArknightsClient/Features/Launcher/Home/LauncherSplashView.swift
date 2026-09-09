// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Shown over the whole window from launch until the initial artwork restore completes, so the
/// launcher opens on a deliberate brand moment instead of an abrupt cut from a dark placeholder
/// to the real artwork a couple of seconds later. Two thin bars grow inward from each edge with
/// their percentage riding above the leading tip, meeting at the center exactly as the real load
/// finishes.
struct LauncherSplashView: View {
	let isComplete: Bool
	@State private var progress: Double = 0
	// `isComplete` is a plain `let`, so the long-running climb/snap tasks below would otherwise
	// only ever see the frozen value from whenever `.task` first started — `@State` storage
	// persists independently of that and is what a running task can actually observe live.
	@State private var completed = false

	private static let gold = Color(red: 0.95, green: 0.78, blue: 0.2)
	private static let barHeight: CGFloat = 3
	private static let labelGap: CGFloat = 22
	// How far the fake climb gets on its own before real completion snaps the rest of the
	// way — never claims 100% before the load has actually finished. If the real load finishes
	// sooner than this, the snap just starts from wherever the climb had actually reached.
	private static let fakeClimbCeiling = 0.92
	private static let fakeClimbDuration: TimeInterval = 0.9
	private static let completionSnapDuration: TimeInterval = 0.25
	// Every step is a plain, unanimated state assignment — deliberately not `withAnimation`.
	// SwiftUI's animation system only diffs the start/end of a transaction and lets non-
	// animatable content (the label text, which of the three labels is showing) jump straight
	// to its target while animatable properties (bar width, label position) interpolate on
	// their own — which visibly desyncs the bars from the percentage they're supposed to match.
	// Stepping the state by hand keeps every dependent value reading the exact same `progress`
	// on every real render, so nothing can drift apart.
	private static let stepInterval: TimeInterval = 1.0 / 30

	var body: some View {
		GeometryReader { proxy in
			let half = proxy.size.width / 2
			let barWidth = half * progress
			let midY = proxy.size.height / 2
			let sidePercentageText = "\(min(99, Int(progress * 100)))%"
			let isDone = progress >= 1
			ZStack {
				Color.black
				bar(width: barWidth).position(x: barWidth / 2, y: midY)
				bar(width: barWidth)
					.position(x: proxy.size.width - barWidth / 2, y: midY)
				// All three labels stay mounted the whole time — only their opacity changes —
				// so the swap from two side labels to one centered "100%" is a plain property
				// change on existing views, not an `if`/`else` identity swap that would need
				// its own cross-fade.
				label(sidePercentageText)
					.opacity(isDone ? 0 : 1)
					.position(x: barWidth, y: midY - Self.labelGap)
				label(sidePercentageText)
					.opacity(isDone ? 0 : 1)
					.position(x: proxy.size.width - barWidth, y: midY - Self.labelGap)
				label("100%")
					.opacity(isDone ? 1 : 0)
					.position(x: half, y: midY - Self.labelGap)
			}
		}
		.ignoresSafeArea()
		.accessibilityHidden(true)
		.task { await climb() }
		.onChange(of: isComplete) { _, complete in
			guard complete else { return }
			completed = true
			Task { await snapToComplete() }
		}
	}

	private func bar(width: CGFloat) -> some View {
		Rectangle().fill(Self.gold).frame(width: width, height: Self.barHeight)
	}

	private func label(_ text: String) -> some View {
		Text(verbatim: text)
			.font(.system(size: 15, weight: .medium))
			.foregroundStyle(Self.gold)
	}

	// Driven by real elapsed time rather than a fixed step count: during launch the main actor
	// is busy with window/runtime setup, so individual sleeps routinely take longer than their
	// nominal duration, and a step-counted climb falls badly behind wall-clock time — landing
	// well short of its ceiling by the time the real load actually finishes.
	private func climb() async {
		guard !completed else { return }
		let start = Date()
		while !completed {
			try? await Task.sleep(for: .seconds(Self.stepInterval))
			guard !completed else { return }
			let fraction = min(1, Date().timeIntervalSince(start) / Self.fakeClimbDuration)
			progress = Self.fakeClimbCeiling * fraction
			if fraction >= 1 { return }
		}
	}

	private func snapToComplete() async {
		let start = Date()
		let startProgress = progress
		while true {
			try? await Task.sleep(for: .seconds(Self.stepInterval))
			let fraction = min(1, Date().timeIntervalSince(start) / Self.completionSnapDuration)
			progress = startProgress + (1 - startProgress) * fraction
			if fraction >= 1 {
				progress = 1
				return
			}
		}
	}
}
