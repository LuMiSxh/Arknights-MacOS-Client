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
	@State private var measuredSize = GameDisplaySize(width: 0, height: 0)
	@State private var locksWidescreen = false

	private var validSize: GameDisplaySize? {
		GameDisplaySize.validatedCustom(width: measuredSize.width, height: measuredSize.height)
	}

	var body: some View {
		VStack(spacing: LauncherTokens.Spacing.panel) {
			Text("\(measuredSize.displayName) points")
				.font(.title2)
				.monospacedDigit()
				.foregroundStyle(theme.textPrimary)
			HStack(spacing: LauncherTokens.Spacing.control) {
				Text("Lock 16:9")
					.foregroundStyle(theme.textSecondary)
				SettingsToggle("Lock 16:9", isOn: $locksWidescreen)
			}
			HStack(spacing: LauncherTokens.Spacing.control) {
				CapsuleActionButton(title: "Cancel", tone: .neutral) {
					dismissWindow(id: GameWindowMeasureView.sceneID)
				}
				CapsuleActionButton(title: "Use This Size", tone: .accent(theme.accentFill)) {
					useMeasuredSize()
				}
				.disabled(validSize == nil)
			}
		}
		.frame(
			minWidth: CGFloat(AppConstants.Game.customWindowMinimum.width),
			minHeight: CGFloat(AppConstants.Game.customWindowMinimum.height)
		)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(WindowAspectRatioLock(isLocked: locksWidescreen))
		.onGeometryChange(for: GameDisplaySize.self) { proxy in
			GameDisplaySize(
				width: Int(proxy.size.width.rounded()), height: Int(proxy.size.height.rounded()))
		} action: {
			measuredSize = $0
		}
	}

	private func useMeasuredSize() {
		guard let size = validSize else { return }
		settings.launchOptions.windowSize = size
		dismissWindow(id: GameWindowMeasureView.sceneID)
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
			window?.contentAspectRatio = isLocked ? NSSize(width: 16, height: 9) : .zero
		}
	}
}
