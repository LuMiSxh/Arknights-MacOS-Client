// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

// Windowed sizes are macOS points; the launcher converts them into the game's pixel resolution.
/// Width and height fields for a custom window size, plus the entry to the measuring window.
struct CustomWindowSizeRow: View {
	@Bindable var settings: LauncherPreferencesController
	let isDisabled: Bool
	@State private var widthText = ""
	@State private var heightText = ""
	@State private var hint: String?
	@Environment(\.launcherTheme) private var theme
	@Environment(\.openWindow) private var openWindow

	private static var limitHint: String {
		let minimum = AppConstants.Game.customWindowMinimum
		let maximum = AppConstants.Game.customWindowMaximumDimension
		return
			"Enter whole points: width \(minimum.width) to \(maximum), height \(minimum.height) to \(maximum)."
	}

	var body: some View {
		SettingsActionRow(
			title: "Custom size",
			detail: hint,
			help:
				"Width and height in points. Press Return to apply. Measure With a Window… reads the size of a resizable window."
		) {
			HStack(spacing: LauncherTokens.Spacing.control) {
				ThemedTextField("Width", text: $widthText, leadingText: "W")
					.frame(width: 96)
				Text("×")
					.foregroundStyle(theme.textSecondary)
				ThemedTextField("Height", text: $heightText, leadingText: "H")
					.frame(width: 96)
				CapsuleActionButton(
					title: "Measure With a Window…", systemImage: "ruler", tone: .neutral,
					presentation: .compact
				) {
					openWindow(id: GameWindowMeasureView.sceneID)
				}
			}
			.disabled(isDisabled)
			.onSubmit { applyTypedSize() }
		}
		.onAppear { showStoredSize() }
		.onChange(of: settings.launchOptions.windowSize) { _, _ in
			hint = nil
			showStoredSize()
		}
	}

	private func showStoredSize() {
		widthText = String(settings.launchOptions.windowSize.width)
		heightText = String(settings.launchOptions.windowSize.height)
	}

	/// Applies both fields together. Invalid input restores the stored size and shows the limits.
	private func applyTypedSize() {
		guard
			let width = Int(widthText.trimmingCharacters(in: .whitespaces)),
			let height = Int(heightText.trimmingCharacters(in: .whitespaces)),
			let size = GameDisplaySize.validatedCustom(width: width, height: height)
		else {
			hint = Self.limitHint
			showStoredSize()
			return
		}
		hint = nil
		settings.launchOptions.windowSize = size
	}
}

/// The window size picker for `GameDisplaySettingsPanel`.
struct GameWindowSizeRow: View {
	@Bindable var settings: LauncherPreferencesController
	let screen: GameScreenMetrics?
	let isDisabled: Bool
	@Binding var showsCustomSize: Bool

	private var options: GameLaunchOptions { settings.launchOptions }

	private enum WindowSizeSelection: Hashable {
		case choice(GameWindowSizeChoice)
		case exact(GameDisplaySize)
		case custom
	}

	var body: some View {
		let exact = GameDisplaySize.windowOptions(
			fitting: screen?.visibleSize, current: options.windowSize
		).map(WindowSizeSelection.exact)
		let choices =
			screen == nil ? [] : GameWindowSizeChoice.allCases.map(WindowSizeSelection.choice)
		return SettingsActionRow(
			title: "Window size",
			help:
				"Measured like the resolutions in System Settings › Displays. The launcher works out the resolution the game draws from this size and the Rendering setting."
		) {
			GlassMenuPicker(
				selection: windowSizeSelection,
				options: (choices + exact + [.custom]).map { ($0, windowSizeTitle($0)) },
				isDisabled: isDisabled,
				dividerBefore: { selection in
					if selection == .custom { return true }
					guard case .exact(let size) = selection,
						let index = exact.firstIndex(of: selection)
					else { return false }
					guard index > 0, case .exact(let previous) = exact[index - 1] else {
						return !choices.isEmpty
					}
					return size.aspectGroup != previous.aspectGroup
				}
			)
		}
	}

	private var windowSizeSelection: Binding<WindowSizeSelection> {
		Binding(
			get: {
				if showsCustomSize { return WindowSizeSelection.custom }
				return screen.flatMap { GameWindowSizeChoice.matching(options.windowSize, on: $0) }
					.map(WindowSizeSelection.choice) ?? .exact(options.windowSize)
			},
			set: { selection in
				showsCustomSize = selection == .custom
				switch selection {
				case .choice(let choice):
					guard let screen else { return }
					settings.launchOptions.windowSize = choice.size(on: screen)
				case .exact(let size):
					settings.launchOptions.windowSize = size
				case .custom:
					break
				}
			}
		)
	}

	private func windowSizeTitle(_ selection: WindowSizeSelection) -> String {
		switch selection {
		case .choice(.fillScreen): "Fill screen"
		case .choice(.leaveRoom): "Compact"
		case .exact(let size): size.displayName
		case .custom: "Custom…"
		}
	}
}
