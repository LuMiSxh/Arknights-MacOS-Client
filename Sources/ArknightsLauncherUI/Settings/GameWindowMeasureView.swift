// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsCustomization
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
		GameWindowMeasurePanel(settings: model.settings, customization: model.customization)
			// Dark like Home: the artwork sits behind every control, whatever the Appearance.
			.launcherTheme(accent: model.customization.accentColor)
			.environment(\.colorScheme, .dark)
	}
}

/// Sits below the `launcherTheme` modifier, so it can read the theme from the environment.
private struct GameWindowMeasurePanel: View {
	let settings: LauncherPreferencesController
	let customization: CustomizationController
	@Environment(\.launcherTheme) private var theme
	@Environment(\.dismissWindow) private var dismissWindow
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var measuredSize = GameDisplaySize(width: 0, height: 0)
	@State private var lockedRatio = LockedRatio.free

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
		// No inner frame: the window edge is the measured area, and an inset frame would read as it.
		VStack(spacing: LauncherTokens.Spacing.content) {
			readout
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			controls
		}
		.padding(LauncherTokens.Spacing.panel)
		.frame(
			minWidth: CGFloat(AppConstants.Game.customWindowMinimum.width),
			minHeight: CGFloat(AppConstants.Game.customWindowMinimum.height)
		)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background { backdrop }
		.background(WindowAspectRatioLock(ratio: lockedRatio.size))
		.onGeometryChange(for: GameDisplaySize.self) { proxy in
			GameDisplaySize(
				width: Int(proxy.size.width.rounded()), height: Int(proxy.size.height.rounded()))
		} action: {
			measuredSize = $0
		}
	}

	/// The hero artwork fills the window, as it fills the game. The scrim keeps the readout
	/// readable over the artwork. The sheet color shows when no artwork is set.
	private var backdrop: some View {
		ZStack {
			if let image = customization.heroArtwork {
				Image(nsImage: image)
					.resizable()
					.scaledToFill()
					.frame(maxWidth: .infinity, maxHeight: .infinity)
					.clipped()
				theme.scrim
			} else {
				theme.sheetSolid
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.ignoresSafeArea()
		.allowsHitTesting(false)
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
					.foregroundStyle(theme.dangerText)
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

	// The same floating glass bar as the Home actions.
	private var controls: some View {
		FloatingActionBar {
			Text("Lock ratio")
				.foregroundStyle(theme.textSecondary)
				.padding(.leading, LauncherTokens.Spacing.control)
			AdaptiveSegmentedControl(
				selection: $lockedRatio,
				options: LockedRatio.allCases
			) { ratio in
				Text(ratio.title)
			}
			CapsuleActionButton(title: "Cancel", tone: .neutral) {
				dismissWindow(id: GameWindowMeasureView.sceneID)
			}
			CapsuleActionButton(title: "Use This Size", tone: .accent) {
				useMeasuredSize()
			}
			.disabled(validSize == nil)
		}
	}

	private func useMeasuredSize() {
		guard let size = validSize else { return }
		settings.launchOptions.windowSize = size
		dismissWindow(id: GameWindowMeasureView.sceneID)
	}
}

/// The aspect ratios of the official client that the measure window can lock to.
private enum LockedRatio: CaseIterable {
	case free, widescreen, tenToSixteen, fourToThree

	var title: String {
		switch self {
		case .free: "Free"
		case .widescreen: "16:9"
		case .tenToSixteen: "16:10"
		case .fourToThree: "4:3"
		}
	}

	var size: NSSize? {
		switch self {
		case .free: nil
		case .widescreen: NSSize(width: 16, height: 9)
		case .tenToSixteen: NSSize(width: 16, height: 10)
		case .fourToThree: NSSize(width: 4, height: 3)
		}
	}
}

/// Keeps the hosting window's content at `ratio` while it is set.
private struct WindowAspectRatioLock: NSViewRepresentable {
	let ratio: NSSize?

	func makeNSView(context: Context) -> AspectRatioView {
		AspectRatioView()
	}

	func updateNSView(_ view: AspectRatioView, context: Context) {
		view.ratio = ratio
	}

	final class AspectRatioView: NSView {
		var ratio: NSSize? {
			didSet { applyAspectRatio() }
		}

		// The window is nil until the view joins it, so the ratio is also set on attach.
		override func viewDidMoveToWindow() {
			super.viewDidMoveToWindow()
			applyAspectRatio()
		}

		private func applyAspectRatio() {
			guard let window else { return }
			if let ratio {
				window.contentAspectRatio = ratio
			} else {
				// Setting the ratio to .zero does not unlock. Resize increments override the ratio.
				window.contentResizeIncrements = NSSize(width: 1, height: 1)
			}
		}
	}
}
