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
				detail: displayModeDetail,
				help: "Applies the next time the game starts."
			) {
				GlassMenuPicker(
					selection: $settings.launchOptions.displayMode,
					options: GameDisplayMode.allCases.map { ($0, displayModeTitle($0)) },
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
				detail: pictureDetail,
				help:
					"Retina: Wine renders at the display's full backing-store resolution.\nMetalFX: Wine renders in macOS points and DXMT upscales every frame 2× with MetalFX spatial scaling. Runtimes without MetalFX support use Lightweight instead.\nLightweight: Wine renders in macOS points and macOS scales the window up.\nApplies on the next game launch."
			) {
				GlassMenuPicker(
					selection: $settings.launchOptions.renderingMode,
					options: GameRenderingMode.allCases.map {
						($0, pictureTitle($0))
					},
					accentColor: accentColor,
					isDisabled: isLocked
				)
			}
			SettingsHairline()
			SettingsActionRow(
				title: "Pointer",
				detail: pointerDetail,
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
			detail: windowSizeDetail(choice),
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
		case .choice(.fillScreen): "Fill my screen"
		case .choice(.leaveRoom): "Leave room for other apps"
		case .exact(let size): size.displayName
		}
	}

	// MARK: Fullscreen detail

	private var fullscreenDetailRow: some View {
		let native = nativeFullscreenSize
		let detail = GameFullscreenDetail.matching(options.fullscreenResolution, native: native)
		var choices = GameFullscreenDetail.available(native: native).map {
			let resolution = $0.resolution(native: native)
			return (resolution, fullscreenDetailTitle($0, resolution: resolution))
		}
		// Keeps an exact resolution picked in the submenu, or on another display, selectable.
		if detail == nil {
			choices.append(
				(
					options.fullscreenResolution,
					fullscreenResolutionTitle(options.fullscreenResolution)
				))
		}
		return SettingsActionRow(
			title: "Detail",
			detail: fullscreenDetailDetail(detail),
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
		case .native:
			// For example "Native (6016 × 3384)", like games label the display's own resolution.
			nativeFullscreenSize.map { "\(Self.nativeResolution) (\($0.displayName))" }
				?? Self.nativeResolution
		case .fixed(let size): resolutionTitle(size)
		}
	}

	private var fullscreenResolution: Binding<GameFullscreenResolution> {
		Binding(
			get: { options.fullscreenResolution },
			set: { settings.launchOptions.selectFullscreen($0, native: nativeFullscreenSize) }
		)
	}

	// MARK: Text

	private static let nativeResolution = "Native"

	private var displayModeDetail: String {
		switch options.displayMode {
		case .fullscreen: "Arknights fills your whole screen."
		case .windowed: "Arknights opens in a window you can move around."
		case .borderlessWindow: "Arknights opens in a window without a title bar."
		}
	}

	private func displayModeTitle(_ mode: GameDisplayMode) -> String {
		switch mode {
		case .fullscreen: "Fullscreen"
		case .windowed: "In a window"
		case .borderlessWindow: "Borderless window"
		}
	}

	private var pictureDetail: String {
		switch options.renderingMode {
		case .retina: "Looks sharpest, but asks the most of your Mac."
		case .metalFX: "Stays smooth on large screens; text looks slightly softer."
		case .lightweight: "Easiest on your battery, but the picture looks softer."
		}
	}

	private func pictureTitle(_ mode: GameRenderingMode) -> String {
		switch mode {
		case .retina: "The sharpest picture · Retina"
		case .metalFX: "Smooth play on big screens · MetalFX"
		case .lightweight: "Longer battery life · Lightweight"
		}
	}

	private var pointerDetail: String {
		settings.usesHardwareCursor
			? "The macOS hardware cursor follows your mouse without delay."
			: "The game draws its own software cursor, which can lag slightly."
	}

	/// `choice` is nil for an exact size picked from the list.
	private func windowSizeDetail(_ choice: GameWindowSizeChoice?) -> String {
		switch choice {
		case .fillScreen?: "Fills your screen, title bar included."
		case .leaveRoom?: "Leaves space for other apps on your screen."
		case nil: "A window of the exact size you picked."
		}
	}

	/// For example "Balanced · 2560 × 1440 (WQHD)".
	private func fullscreenDetailTitle(
		_ detail: GameFullscreenDetail, resolution: GameFullscreenResolution
	) -> String {
		let size =
			switch resolution {
			case .native: Self.nativeResolution
			case .fixed(let size): resolutionTitle(size)
			}
		return switch detail {
		case .full: "Full detail · \(size) (recommended)"
		case .balanced: "Balanced · \(size)"
		case .lighter: "Lighter · \(size)"
		}
	}

	/// `detail` is nil for an exact resolution picked from the submenu.
	private func fullscreenDetailDetail(_ detail: GameFullscreenDetail?) -> String {
		switch detail {
		case .full?: "Uses every pixel of your screen. Best on most Macs."
		case .balanced?: "A little easier on your Mac, still crisp."
		case .lighter?: "Easiest on your Mac, but the picture looks softer."
		case nil: "A resolution you picked yourself."
		}
	}

	private func fullscreenResolutionTitle(_ choice: GameFullscreenResolution) -> String {
		switch choice {
		case .native: Self.nativeResolution
		case .fixed(let size): size.displayName
		}
	}

	/// For example "2560 × 1440 (WQHD)"; resolutions without a common name stay plain.
	private func resolutionTitle(_ size: GameDisplaySize) -> String {
		standardName(size).map { "\(size.displayName) (\($0))" } ?? size.displayName
	}

	/// Common names, only for the exact resolutions they stand for.
	private func standardName(_ size: GameDisplaySize) -> String? {
		switch (size.width, size.height) {
		case (1280, 720): "HD"
		case (1920, 1080): "Full HD"
		case (2560, 1440): "WQHD"
		case (3840, 2160): "4K"
		case (5120, 2880): "5K"
		case (6016, 3384): "6K"
		case (7680, 4320): "8K"
		default: nil
		}
	}
}
