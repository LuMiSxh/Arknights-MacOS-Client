// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct GameDisplaySettingsPanel: View {
	@Environment(\.launcherTheme) private var theme
	@Bindable var settings: LauncherPreferencesController
	let isLocked: Bool
	/// nil while runtime discovery runs. False means the game falls back to Standard.
	let metalFXSpatialUpscalingSupported: Bool?
	@State private var screens = GameScreenMonitor()
	/// Set by the Custom… choice. Shows the width and height fields for the stored size.
	@State private var showsCustomSize = false

	private var options: GameLaunchOptions { settings.launchOptions }
	private var isSizeLocked: Bool { options.usesGameSettings || isLocked }
	/// The screen the game opens on, from the connected displays.
	private var resolution: GameScreenResolution? { screens.list.resolve(options.display) }
	private var screen: GameScreenMetrics? { resolution?.metrics }
	private var nativeFullscreenSize: GameDisplaySize? { resolution?.fullscreenDisplay.pixelSize }
	private var plan: GameDisplayPlan {
		GameDisplayPlan(
			options: options, backingScaleFactor: resolution?.screen.backingScaleFactor ?? 1,
			fullscreenDisplay: resolution?.fullscreenDisplay)
	}
	private var showsInGameResolutionNote: Bool {
		options.usesGameSettings && plan.gamePixelsPerPoint > 1
			&& !settings.dismissedInGameResolutionNote
	}

	var body: some View {
		SettingsPanel(title: "Display") {
			if showsDisplayRow {
				SettingsActionRow(
					title: "Game display",
					detail: displayDetail,
					help:
						"Fullscreen and the window size use this display. Primary display follows the display with the menu bar. Applies the next time the game starts."
				) {
					GlassMenuPicker(
						selection: $settings.launchOptions.display,
						options: displayChoices,
						isDisabled: isLocked
					)
				}
				SettingsHairline()
			}
			SettingsActionRow(
				title: "Override in-game display settings",
				detail:
					"On: the launcher sets mode and resolution at each start. Off: the game uses its own settings.",
				help:
					"Arknights’ own resolution setting counts the pixels the game draws. With the sharpest picture, every window point holds several pixels, so an in-game resolution opens a smaller window than its number suggests. The launcher passes the converted resolution to the game on every start."
			) {
				SettingsToggle(
					"Override in-game display settings",
					isOn: launcherDisplayControl
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
					isDisabled: isSizeLocked
				)
			}
			SettingsHairline()
			if options.displayMode == .fullscreen {
				GameFullscreenResolutionRow(
					settings: settings,
					nativeFullscreenSize: nativeFullscreenSize,
					isDisabled: isSizeLocked
				)
			} else {
				GameWindowSizeRow(
					settings: settings,
					screen: screen,
					isDisabled: isSizeLocked,
					showsCustomSize: $showsCustomSize
				)
				if showsCustomSize {
					SettingsHairline()
					CustomWindowSizeRow(settings: settings, isDisabled: isSizeLocked)
				}
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
						.foregroundStyle(theme.textSecondary)
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
					isDisabled: isLocked
				) { usesMacPointer in
					Text(usesMacPointer ? "macOS" : "Game")
				}
			}
			if options.usesGameSettings {
				SettingsHairline()
				Text("The game uses the display settings chosen inside Arknights.")
					.font(.callout)
					.foregroundStyle(theme.textSecondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.task { await screens.observe() }
	}

	// MARK: Game display

	/// The row appears with several displays, or when the saved display is not connected.
	private var showsDisplayRow: Bool {
		screens.list.screens.count > 1 || resolution?.isFallback == true
	}

	private var displayChoices: [(value: GameDisplayIdentity?, title: String)] {
		var choices: [(value: GameDisplayIdentity?, title: String)] = [(nil, "Primary display")]
		choices += screens.list.screens.map {
			(value: $0.identity as GameDisplayIdentity?, title: $0.identity.name)
		}
		if let saved = options.display, resolution?.isFallback == true {
			choices.append((saved, "\(saved.name) (not connected)"))
		}
		return choices
	}

	private var displayDetail: String? {
		guard resolution?.isFallback == true, let saved = options.display else { return nil }
		return "\(saved.name) is not connected. The game opens on the primary display."
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
		HStack(alignment: .firstTextBaseline, spacing: LauncherTokens.Spacing.control) {
			Image(systemName: "info.circle")
				.foregroundStyle(theme.textSecondary)
				.accessibilityHidden(true)
			Text(
				"Resolutions inside Arknights count the pixels the game draws. With Retina rendering, "
					+ "choose \(options.windowSize.scaled(by: plan.gamePixelsPerPoint).displayName) in the game for a "
					+ "\(options.windowSize.displayName) window."
			)
			.font(.caption)
			.foregroundStyle(theme.textSecondary)
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

}
