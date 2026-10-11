// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

/// Where the game appears, how big it is, and how its picture and pointer behave, in plain terms.
/// Windowed sizes are macOS points; the launcher converts them into the game's pixel resolution.
struct GameDisplaySettingsPanel: View {
	@Bindable var settings: LauncherPreferencesController
	let isLocked: Bool
	package let accentColor: Color

	private var options: GameLaunchOptions { settings.launchOptions }
	private var isSizeLocked: Bool { options.usesGameSettings || isLocked }
	private var screen: GameScreenMetrics? { GameScreenMetrics.main }
	private var nativeFullscreenSize: GameDisplaySize? { GameFullscreenDisplay.primary?.pixelSize }

	var body: some View {
		SettingsPanel(title: "Display", systemImage: "display") {
			SettingsActionRow(
				title: "Show the game",
				detail: SettingsStrings.displayModeDetail(options.displayMode),
				help: "Applies the next time the game starts."
			) {
				GlassMenuPicker(
					selection: $settings.launchOptions.displayMode,
					options: GameDisplayMode.allCases.map { ($0, SettingsStrings.displayMode($0)) },
					accentColor: accentColor,
					isDisabled: isSizeLocked
				)
			}
			SettingsHairline()
			if options.displayMode == .fullscreen {
				fullscreenDetailRow
			} else {
				windowSizeRow
			}
			SettingsHairline()
			SettingsActionRow(
				title: "Picture",
				detail: SettingsStrings.pictureDetail(options.renderingMode),
				help:
					"Retina: Wine renders at the display's full backing-store resolution.\nMetalFX: Wine renders in macOS points and DXMT upscales every frame 2× with MetalFX spatial scaling. Runtimes without MetalFX support use Lightweight instead.\nLightweight: Wine renders in macOS points and macOS scales the window up.\nApplies on the next game launch."
			) {
				GlassMenuPicker(
					selection: $settings.launchOptions.renderingMode,
					options: GameRenderingMode.allCases.map {
						($0, SettingsStrings.pictureTitle($0))
					},
					accentColor: accentColor,
					isDisabled: isLocked
				)
			}
			SettingsHairline()
			SettingsActionRow(
				title: "Pointer",
				detail: SettingsStrings.pointerDetail(usesMacPointer: settings.usesHardwareCursor),
				help:
					"Asks the runtime to hide the game's software-drawn cursor so the macOS hardware cursor shows instead. Runtimes without this capability keep the game cursor. Applies on the next game launch."
			) {
				AdaptiveSegmentedControl(
					selection: $settings.usesHardwareCursor,
					options: [true, false],
					accentColor: accentColor,
					isDisabled: isLocked
				) { usesMacPointer in
					Text(usesMacPointer ? "Your Mac's pointer" : "Arknights' cursor")
				}
			}
			SettingsHairline()
			Text(
				GameDisplaySummary.text(for: options, screen: screen, native: nativeFullscreenSize)
			)
			.font(.callout)
			.foregroundStyle(.secondary)
			.fixedSize(horizontal: false, vertical: true)
		}
	}

	// MARK: Window size

	private enum WindowSizeSelection: Hashable {
		case choice(GameWindowSizeChoice)
		case exact(GameDisplaySize)
	}

	private var windowSizeRow: some View {
		let choice = screen.flatMap { GameWindowSizeChoice.matching(options.windowSize, on: $0) }
		let exact = GameDisplaySize.windowOptions(
			fitting: screen?.visibleSize, current: options.windowSize
		).map(WindowSizeSelection.exact)
		let choices =
			screen == nil ? [] : GameWindowSizeChoice.allCases.map(WindowSizeSelection.choice)
		return SettingsActionRow(
			title: "Window size",
			detail: SettingsStrings.windowSizeDetail(choice),
			help:
				"Measured like the resolutions in System Settings › Displays. The launcher works out the resolution the game draws from this size and the Picture setting."
		) {
			GlassMenuPicker(
				selection: windowSizeSelection,
				options: (choices + exact).map { ($0, windowSizeTitle($0)) },
				accentColor: accentColor,
				isDisabled: isSizeLocked,
				dividerBefore: { !choices.isEmpty && $0 == exact.first }
			)
		}
	}

	private var windowSizeSelection: Binding<WindowSizeSelection> {
		Binding(
			get: {
				screen.flatMap { GameWindowSizeChoice.matching(options.windowSize, on: $0) }
					.map(WindowSizeSelection.choice) ?? .exact(options.windowSize)
			},
			set: { selection in
				switch selection {
				case .choice(let choice):
					guard let screen else { return }
					settings.launchOptions.windowSize = choice.size(on: screen)
				case .exact(let size):
					settings.launchOptions.windowSize = size
				}
			}
		)
	}

	private func windowSizeTitle(_ selection: WindowSizeSelection) -> String {
		switch selection {
		case .choice(let choice): SettingsStrings.windowSizeTitle(choice)
		case .exact(let size): size.displayName
		}
	}

	// MARK: Fullscreen detail

	private var fullscreenDetailRow: some View {
		let native = nativeFullscreenSize
		let detail = GameFullscreenDetail.matching(options.fullscreenResolution, native: native)
		var choices = GameFullscreenDetail.available(native: native).map {
			let resolution = $0.resolution(native: native)
			return (resolution, SettingsStrings.fullscreenDetailTitle($0, resolution: resolution))
		}
		// Keeps an exact resolution picked in the submenu, or on another display, selectable.
		if detail == nil {
			choices.append(
				(
					options.fullscreenResolution,
					SettingsStrings.fullscreenResolutionTitle(options.fullscreenResolution)
				))
		}
		return SettingsActionRow(
			title: "Detail",
			detail: SettingsStrings.fullscreenDetailDetail(detail),
			help:
				"Fullscreen fills the display with the menu bar. Full detail matches that display exactly, the sharpest choice; lower resolutions are scaled up to fill it. With the Smooth and Battery picture settings, the game draws half the width and height and scales the picture up, so every resolution needs less graphics power."
		) {
			GlassMenuPicker(
				selection: fullscreenResolution,
				options: choices,
				accentColor: accentColor,
				isDisabled: isSizeLocked,
				trailingMenuItems: { AnyView(exactResolutionMenu) }
			)
		}
	}

	private var exactResolutionMenu: some View {
		Menu("Exact resolution") {
			ForEach(GameFullscreenResolution.choices(native: nativeFullscreenSize), id: \.self) {
				choice in
				Button {
					fullscreenResolution.wrappedValue = choice
				} label: {
					let title = exactResolutionTitle(choice)
					if choice == options.fullscreenResolution {
						Label(title, systemImage: "checkmark")
					} else {
						Text(title)
					}
				}
			}
		}
	}

	private func exactResolutionTitle(_ choice: GameFullscreenResolution) -> String {
		switch choice {
		case .native: SettingsStrings.nativeResolutionTitle(nativeFullscreenSize)
		case .fixed(let size): SettingsStrings.resolutionTitle(size)
		}
	}

	private var fullscreenResolution: Binding<GameFullscreenResolution> {
		Binding(
			get: { options.fullscreenResolution },
			set: { settings.launchOptions.selectFullscreen($0, native: nativeFullscreenSize) }
		)
	}
}
