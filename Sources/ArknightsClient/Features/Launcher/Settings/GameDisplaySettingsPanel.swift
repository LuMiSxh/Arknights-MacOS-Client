// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Where the game appears, how big it is, and how its picture and pointer behave, in plain terms.
/// Windowed sizes are macOS points; the launcher converts them into the game's pixel resolution.
struct GameDisplaySettingsPanel: View {
	@Bindable var settings: LauncherPreferencesController
	let isLocked: Bool
	let accentColor: Color

	private var options: GameLaunchOptions { settings.launchOptions }
	private var isSizeLocked: Bool { options.usesGameSettings || isLocked }
	private var screen: GameScreenMetrics? { GameScreenMetrics.main }
	private var nativeFullscreenSize: GameDisplaySize? { GameFullscreenDisplay.primary?.pixelSize }

	var body: some View {
		SettingsPanel(title: SettingsStrings.displayPanel, systemImage: "display") {
			SettingsActionRow(
				title: SettingsStrings.showTheGame,
				detail: SettingsStrings.displayModeDetail(options.displayMode),
				help: SettingsStrings.showTheGameHelp
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
				title: SettingsStrings.picture,
				detail: SettingsStrings.pictureDetail(options.renderingMode),
				help: SettingsStrings.pictureHelp
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
				title: SettingsStrings.pointer,
				detail: SettingsStrings.pointerDetail(usesMacPointer: settings.usesHardwareCursor),
				help: SettingsStrings.pointerHelp
			) {
				AdaptiveSegmentedControl(
					selection: $settings.usesHardwareCursor,
					options: [true, false],
					accentColor: accentColor,
					isDisabled: isLocked
				) { usesMacPointer in
					Text(usesMacPointer ? SettingsStrings.macPointer : SettingsStrings.gamePointer)
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
			title: SettingsStrings.windowSize,
			detail: SettingsStrings.windowSizeDetail(choice),
			help: SettingsStrings.windowSizeHelp
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
			($0.resolution(native: native), SettingsStrings.fullscreenDetailTitle($0))
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
			title: SettingsStrings.fullscreenDetail,
			detail: SettingsStrings.fullscreenDetailDetail(detail),
			help: SettingsStrings.fullscreenDetailHelp
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
		Menu(SettingsStrings.exactResolution) {
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
