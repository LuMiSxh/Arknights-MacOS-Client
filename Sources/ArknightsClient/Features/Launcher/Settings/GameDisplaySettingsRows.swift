// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

/// Rendering, window mode, and size controls shared by General settings and the setup assistant.
/// Windowed sizes are macOS points; the launcher converts them into the game's pixel resolution.
struct GameDisplaySettingsRows: View {
	@Bindable var settings: LauncherPreferencesController
	let isLocked: Bool
	let accentColor: Color
	@Environment(\.displayScale) private var displayScale

	private var options: GameLaunchOptions { settings.launchOptions }
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
		SettingsActionRow(
			title: SettingsStrings.rendering,
			detail: SettingsStrings.renderingModeDetail(options.renderingMode),
			help: SettingsStrings.renderingHelp
		) {
			GlassMenuPicker(
				selection: $settings.launchOptions.renderingMode,
				options: GameRenderingMode.allCases.map {
					($0, SettingsStrings.renderingMode($0))
				},
				accentColor: accentColor,
				isDisabled: isLocked
			)
		}
		SettingsHairline()
		SettingsActionRow(
			title: SettingsStrings.launcherDisplayControl,
			detail: SettingsStrings.launcherDisplayControlDetail,
			help: SettingsStrings.launcherDisplayControlHelp
		) {
			SettingsToggle(
				SettingsStrings.launcherDisplayControl,
				isOn: launcherDisplayControl,
				accentColor: accentColor
			)
			.disabled(isLocked)
		}
		if showsInGameResolutionNote {
			inGameResolutionNote
		}
		SettingsHairline()
		SettingsActionRow(
			title: SettingsStrings.windowMode,
			detail: SettingsStrings.windowModeDetail
		) {
			GlassMenuPicker(
				selection: $settings.launchOptions.displayMode,
				options: GameDisplayMode.allCases.map {
					($0, SettingsStrings.displayMode($0))
				},
				accentColor: accentColor,
				isDisabled: options.usesGameSettings || isLocked
			)
		}
		SettingsHairline()
		if options.displayMode == .fullscreen {
			SettingsActionRow(
				title: SettingsStrings.gameResolution,
				detail: sizeDetail(fallback: SettingsStrings.gameResolutionDetail),
				help: SettingsStrings.gameResolutionHelp
			) {
				GlassMenuPicker(
					selection: fullscreenResolution,
					options: fullscreenChoices.map {
						($0, SettingsStrings.fullscreenResolutionTitle($0))
					},
					accentColor: accentColor,
					isDisabled: options.usesGameSettings || isLocked,
					listTitle: { fullscreenListTitle($0) },
					menuTitle: SettingsStrings.gameResolutionMenuTitle
				)
			}
		} else {
			SettingsActionRow(
				title: SettingsStrings.windowSize,
				detail: sizeDetail(fallback: SettingsStrings.windowSizeDetail),
				help: SettingsStrings.windowSizeHelp
			) {
				GlassMenuPicker(
					selection: $settings.launchOptions.windowSize,
					options: GameDisplaySize.windowOptions(
						fitting: NSScreen.main?.visibleFrame.size,
						current: options.windowSize
					).map { ($0, $0.displayName) },
					accentColor: accentColor,
					isDisabled: options.usesGameSettings || isLocked,
					menuTitle: SettingsStrings.windowSizeMenuTitle
				)
			}
		}
	}

	private var launcherDisplayControl: Binding<Bool> {
		Binding(
			get: { !settings.launchOptions.usesGameSettings },
			set: { settings.launchOptions.usesGameSettings = !$0 }
		)
	}

	private var fullscreenResolution: Binding<GameFullscreenResolution> {
		Binding(
			get: { options.fullscreenResolution },
			set: { settings.launchOptions.selectFullscreen($0, native: nativeFullscreenSize) }
		)
	}

	/// Keeps a size picked on another display selectable, like the window size list.
	private var fullscreenChoices: [GameFullscreenResolution] {
		let choices = GameFullscreenResolution.choices(native: nativeFullscreenSize)
		return choices.contains(options.fullscreenResolution)
			? choices : choices + [options.fullscreenResolution]
	}

	/// Names well-known resolutions in the open menu; the drawn size is in the description.
	private func fullscreenListTitle(_ choice: GameFullscreenResolution) -> String {
		switch choice {
		case .native: SettingsStrings.nativeResolutionTitle(nativeFullscreenSize)
		case .fixed(let size): SettingsStrings.resolutionTitle(size)
		}
	}

	private var nativeFullscreenSize: GameDisplaySize? { GameFullscreenDisplay.primary?.pixelSize }

	private func sizeDetail(fallback: String) -> String {
		guard let renderSize = plan.renderSize else { return fallback }
		return SettingsStrings.renderSummary(
			plan, size: renderSize,
			window: options.displayMode == .fullscreen ? nil : options.windowSize)
	}

	private var inGameResolutionNote: some View {
		HStack(alignment: .firstTextBaseline, spacing: LauncherVisuals.Spacing.control) {
			Image(systemName: "info.circle")
				.foregroundStyle(.secondary)
				.accessibilityHidden(true)
			Text(
				SettingsStrings.inGameResolutionNote(
					window: options.windowSize, pixelsPerPoint: plan.gamePixelsPerPoint)
			)
			.font(.caption)
			.foregroundStyle(.secondary)
			.fixedSize(horizontal: false, vertical: true)
			.frame(maxWidth: .infinity, alignment: .leading)
			CapsuleActionButton(
				title: SettingsStrings.gotIt, systemImage: "checkmark",
				tone: .neutral, presentation: .compact
			) {
				settings.dismissedInGameResolutionNote = true
			}
		}
	}
}
