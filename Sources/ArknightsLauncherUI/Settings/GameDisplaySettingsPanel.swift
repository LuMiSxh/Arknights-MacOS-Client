// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

// Windowed sizes are macOS points; the launcher converts them into the game's pixel resolution.
struct GameDisplaySettingsPanel: View {
	@Bindable var settings: LauncherPreferencesController
	let isLocked: Bool
	package let accentColor: Color
	/// nil while runtime discovery runs. False means the game falls back to Standard.
	let metalFXSpatialUpscalingSupported: Bool?
	@Environment(\.displayScale) private var displayScale

	private var options: GameLaunchOptions { settings.launchOptions }
	private var isSizeLocked: Bool { options.usesGameSettings || isLocked }
	private var screen: GameScreenMetrics? { GameScreenMetrics.main }
	private var nativeFullscreenSize: GameDisplaySize? { GameFullscreenDisplay.primary?.pixelSize }
	private var plan: GameDisplayPlan {
		GameDisplayPlan(
			options: options, backingScaleFactor: displayScale,
			fullscreenDisplay: GameFullscreenDisplay.primary)
	}
	private var showsInGameResolutionNote: Bool {
		options.usesGameSettings && plan.gamePixelsPerPoint > 1
			&& !settings.dismissedInGameResolutionNote
	}

	var body: some View {
		SettingsPanel(title: "Display", systemImage: "display") {
			SettingsActionRow(
				title: "Override in-game display settings",
				detail:
					"On: the launcher sets mode and resolution at each start. Off: the game uses its own settings.",
				help:
					"Arknights' own resolution setting counts the pixels the game draws. With the sharpest picture, every window point holds several pixels, so an in-game resolution opens a smaller window than its number suggests. The launcher passes the converted resolution to the game on every start."
			) {
				SettingsToggle(
					"Override in-game display settings",
					isOn: launcherDisplayControl,
					accentColor: accentColor
				)
				.disabled(isLocked)
			}
			SettingsHairline()
			SettingsActionRow(
				title: "Display mode",
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
				fullscreenResolutionRow
			} else {
				windowSizeRow
			}
			SettingsHairline()
			SettingsActionRow(
				title: "Rendering",
				detail: renderingDetail,
				help:
					"Retina: the game renders every pixel of the display.\nMetalFX: the game renders one pixel per point and MetalFX upscales each frame. Falls back to Standard if the runtime lacks support.\nStandard: the game renders one pixel per point and macOS scales the window. Softer image, lowest GPU load.\nApplies on next launch."
			) {
				GlassMenuPicker(
					selection: $settings.launchOptions.renderingMode,
					options: GameRenderingMode.allCases.map { ($0, renderingTitle($0)) },
					accentColor: accentColor,
					isDisabled: isLocked
				)
			}
			SettingsHairline()
			if let renderSize = plan.renderSize {
				SettingsActionRow(
					title: "Render resolution",
					detail: scalingDetail
				) {
					Text(renderSize.displayName)
						.monospacedDigit()
						.foregroundStyle(.secondary)
				}
				SettingsHairline()
			}
			if showsInGameResolutionNote {
				inGameResolutionNote
				SettingsHairline()
			}
			SettingsActionRow(
				title: "Cursor",
				help:
					"macOS cursor = hardware cursor. Older runtimes keep the game cursor. Applies on next launch."
			) {
				AdaptiveSegmentedControl(
					selection: $settings.usesHardwareCursor,
					options: [true, false],
					accentColor: accentColor,
					isDisabled: isLocked
				) { usesMacPointer in
					Text(usesMacPointer ? "macOS" : "Game")
				}
			}
			if options.usesGameSettings {
				SettingsHairline()
				Text("The game uses the display settings chosen inside Arknights.")
					.font(.callout)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
	}

	// MARK: Window size

	private enum WindowSizeSelection: Hashable {
		case choice(GameWindowSizeChoice)
		case exact(GameDisplaySize)
	}

	private var windowSizeRow: some View {
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
		case .choice(.fillScreen): "Fill screen"
		case .choice(.leaveRoom): "Compact"
		case .exact(let size): size.displayName
		}
	}

	// MARK: Fullscreen resolution

	private var fullscreenResolutionRow: some View {
		var resolutions = GameFullscreenResolution.choices(native: nativeFullscreenSize)
		// Keeps a resolution saved for another display selectable.
		if !resolutions.contains(options.fullscreenResolution) {
			resolutions.append(options.fullscreenResolution)
		}
		let choices = resolutions.map { ($0, resolutionChoiceTitle($0)) }
		return SettingsActionRow(
			title: "Resolution",
			help:
				"Fullscreen fills the display with the menu bar. Native matches that display exactly; lower resolutions are scaled up to fill it. With MetalFX or Standard rendering, the game draws one pixel per point, fewer pixels than the resolution on a Retina display, so every resolution needs less graphics power."
		) {
			GlassMenuPicker(
				selection: fullscreenResolution,
				options: choices,
				accentColor: accentColor,
				isDisabled: isSizeLocked
			)
		}
	}

	private func resolutionChoiceTitle(_ choice: GameFullscreenResolution) -> String {
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

	// MARK: Override and render resolution

	private var launcherDisplayControl: Binding<Bool> {
		Binding(
			get: { !settings.launchOptions.usesGameSettings },
			set: { settings.launchOptions.usesGameSettings = !$0 }
		)
	}

	private var scalingDetail: String {
		switch plan.scaling {
		case .native: "Shown without scaling."
		case .metalFX: "MetalFX upscales it to fit your screen."
		case .stretched: "macOS stretches it to fit your screen."
		}
	}

	private var inGameResolutionNote: some View {
		HStack(alignment: .firstTextBaseline, spacing: LauncherVisuals.Spacing.control) {
			Image(systemName: "info.circle")
				.foregroundStyle(.secondary)
				.accessibilityHidden(true)
			Text(
				"Resolutions inside Arknights count the pixels the game draws. With Retina rendering, "
					+ "choose \(options.windowSize.scaled(by: plan.gamePixelsPerPoint).displayName) in the game for a "
					+ "\(options.windowSize.displayName) window."
			)
			.font(.caption)
			.foregroundStyle(.secondary)
			.fixedSize(horizontal: false, vertical: true)
			.frame(maxWidth: .infinity, alignment: .leading)
			CapsuleActionButton(
				title: "Got It", systemImage: "checkmark",
				tone: .neutral, presentation: .compact
			) {
				settings.dismissedInGameResolutionNote = true
			}
		}
	}

	// MARK: Text

	private static let nativeResolution = "Native"

	private var displayModeDetail: String? {
		options.displayMode == .borderlessWindow ? "Window without a title bar." : nil
	}

	private func displayModeTitle(_ mode: GameDisplayMode) -> String {
		switch mode {
		case .fullscreen: "Fullscreen"
		case .windowed: "Windowed"
		case .borderlessWindow: "Borderless window"
		}
	}

	private var renderingDetail: String? {
		guard options.renderingMode == .metalFX, metalFXSpatialUpscalingSupported == false else {
			return nil
		}
		return "This runtime has no MetalFX. The game uses Standard rendering."
	}

	private func renderingTitle(_ mode: GameRenderingMode) -> String {
		switch mode {
		case .retina: "Retina"
		case .metalFX:
			metalFXSpatialUpscalingSupported == false ? "MetalFX (unavailable)" : "MetalFX"
		case .standard: "Standard"
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
