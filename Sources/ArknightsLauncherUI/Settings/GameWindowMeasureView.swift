// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import SwiftUI

/// A resizable window that shows its content size. "Use This Size" stores that size as the
/// windowed game size. It starts nothing and does not change the launcher's activity.
package struct GameWindowMeasureView: View {
	/// Identifies the `Window` scene that opens this view.
	package static let sceneID = "game-window-measure"

	let model: LauncherViewModel

	package init(model: LauncherViewModel) {
		self.model = model
	}

	package var body: some View {
		GameWindowMeasurePanel(settings: model.settings)
			.launcherTheme(accent: model.customization.accentColor)
	}
}

/// Sits below the `launcherTheme` modifier, so it can read the theme from the environment.
private struct GameWindowMeasurePanel: View {
	let settings: LauncherPreferencesController
	@Environment(\.launcherTheme) private var theme
	@Environment(\.dismissWindow) private var dismissWindow
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var measuredSize = GameDisplaySize(width: 0, height: 0)
	@State private var locksWidescreen = false

	private var validSize: GameDisplaySize? {
		GameDisplaySize.validatedCustom(width: measuredSize.width, height: measuredSize.height)
	}

	/// Names the limit that the measured size breaks, or nil when the size can be used.
	private var sizeLimitHint: String? {
		guard validSize == nil else { return nil }
		let minimum = AppConstants.Game.customWindowMinimum
		let isBelowMinimum =
			measuredSize.width < minimum.width || measuredSize.height < minimum.height
		return isBelowMinimum ? "Too small" : "Too large"
	}

	var body: some View {
		VStack(spacing: LauncherTokens.Spacing.content) {
			DimensionLabel(value: measuredSize.width, axis: .horizontal)
			HStack(spacing: LauncherTokens.Spacing.content) {
				DimensionLabel(value: measuredSize.height, axis: .vertical)
				measuringFrame
			}
			controls
		}
		.padding(LauncherTokens.Spacing.panel)
		.frame(
			minWidth: CGFloat(AppConstants.Game.customWindowMinimum.width),
			minHeight: CGFloat(AppConstants.Game.customWindowMinimum.height)
		)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background { theme.sheetSolid.ignoresSafeArea() }
		.background(WindowAspectRatioLock(isLocked: locksWidescreen))
		.onGeometryChange(for: GameDisplaySize.self) { proxy in
			GameDisplaySize(
				width: Int(proxy.size.width.rounded()), height: Int(proxy.size.height.rounded()))
		} action: {
			measuredSize = $0
		}
	}

	/// The frame fills the space that the labels and controls leave, so it tracks the window size.
	private var measuringFrame: some View {
		ZStack {
			RoundedRectangle(cornerRadius: LauncherTokens.Radius.field)
				.strokeBorder(
					theme.hairline,
					style: StrokeStyle(lineWidth: LauncherVisuals.Spacing.hairline, dash: [6, 4]))
			CornerTicks()
				.stroke(theme.textTertiary, lineWidth: 1.5)
			readout
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}

	private var readout: some View {
		VStack(spacing: LauncherTokens.Spacing.compact) {
			Text(measuredSize.displayName)
				.font(.largeTitle.weight(.medium))
				.monospacedDigit()
				.foregroundStyle(validSize == nil ? theme.textSecondary : theme.textPrimary)
			Text("\(aspectRatioText) · points")
				.font(.callout)
				.monospacedDigit()
				.foregroundStyle(theme.textSecondary)
			if let hint = sizeLimitHint {
				Text(hint)
					.font(.callout.weight(.medium))
					.foregroundStyle(LauncherVisuals.dangerForeground)
					.transition(.opacity)
			}
		}
		.animation(
			LauncherMotion.animation(for: .state, reduceMotion: reduceMotion), value: sizeLimitHint)
	}

	/// "16:9" and "16:10" match within 1%. Other ratios reduce to small whole numbers, else a decimal.
	private var aspectRatioText: String {
		let width = measuredSize.width
		let height = measuredSize.height
		guard width > 0, height > 0 else { return "—" }
		let ratio = Double(width) / Double(height)
		for (label, target) in [("16:9", 16.0 / 9.0), ("16:10", 1.6)]
		where abs(ratio - target) / target < 0.01 {
			return label
		}
		let divisor = Self.greatestCommonDivisor(width, height)
		let reducedWidth = width / divisor
		let reducedHeight = height / divisor
		guard max(reducedWidth, reducedHeight) > 20 else {
			return "\(reducedWidth):\(reducedHeight)"
		}
		return String(format: "%.2f:1", ratio)
	}

	private static func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
		b == 0 ? a : greatestCommonDivisor(b, a % b)
	}

	private var controls: some View {
		HStack(spacing: LauncherTokens.Spacing.control) {
			Text("Lock 16:9")
				.foregroundStyle(theme.textSecondary)
			SettingsToggle("Lock 16:9", isOn: $locksWidescreen)
			Spacer(minLength: LauncherTokens.Spacing.content)
			CapsuleActionButton(title: "Cancel", tone: .neutral) {
				dismissWindow(id: GameWindowMeasureView.sceneID)
			}
			CapsuleActionButton(title: "Use This Size", tone: .accent(theme.accentFill)) {
				useMeasuredSize()
			}
			.disabled(validSize == nil)
		}
		.padding(.horizontal, LauncherTokens.Spacing.panel)
		.padding(.vertical, LauncherTokens.Spacing.content)
		.launcherSurface(.group)
	}

	private func useMeasuredSize() {
		guard let size = validSize else { return }
		settings.launchOptions.windowSize = size
		dismissWindow(id: GameWindowMeasureView.sceneID)
	}
}

/// A width or height readout along one edge of the measuring frame.
private struct DimensionLabel: View {
	let value: Int
	let axis: Axis
	@Environment(\.launcherTheme) private var theme

	var body: some View {
		Text("\(value)")
			.font(.caption.monospacedDigit())
			.foregroundStyle(theme.textTertiary)
			.fixedSize()
			.rotationEffect(.degrees(axis == .vertical ? -90 : 0))
			.frame(
				maxWidth: axis == .horizontal ? .infinity : nil,
				maxHeight: axis == .vertical ? .infinity : nil)
	}
}

/// Short L-shaped ticks at the four corners of the measuring frame.
private struct CornerTicks: Shape {
	nonisolated func path(in rect: CGRect) -> Path {
		let length: CGFloat = 12
		var path = Path()
		for horizontal in [CGFloat(1), -1] {
			for vertical in [CGFloat(1), -1] {
				let corner = CGPoint(
					x: horizontal > 0 ? rect.minX : rect.maxX,
					y: vertical > 0 ? rect.minY : rect.maxY)
				path.move(to: CGPoint(x: corner.x + horizontal * length, y: corner.y))
				path.addLine(to: corner)
				path.addLine(to: CGPoint(x: corner.x, y: corner.y + vertical * length))
			}
		}
		return path
	}
}

/// Keeps the hosting window's content at 16:9 while `isLocked` is true.
private struct WindowAspectRatioLock: NSViewRepresentable {
	let isLocked: Bool

	func makeNSView(context: Context) -> AspectRatioView {
		AspectRatioView()
	}

	func updateNSView(_ view: AspectRatioView, context: Context) {
		view.isLocked = isLocked
	}

	final class AspectRatioView: NSView {
		var isLocked = false {
			didSet { applyAspectRatio() }
		}

		// The window is nil until the view joins it, so the ratio is also set on attach.
		override func viewDidMoveToWindow() {
			super.viewDidMoveToWindow()
			applyAspectRatio()
		}

		private func applyAspectRatio() {
			guard let window else { return }
			if isLocked {
				window.contentAspectRatio = NSSize(width: 16, height: 9)
			} else {
				// Setting the ratio to .zero does not unlock. Resize increments override the ratio.
				window.contentResizeIncrements = NSSize(width: 1, height: 1)
			}
		}
	}
}
