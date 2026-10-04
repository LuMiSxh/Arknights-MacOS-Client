// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Collapsed by default: who sizes the game, the exact size it draws, and the performance and
/// diagnostics launch options.
struct GameAdvancedSettingsPanel: View {
	@Bindable var settings: LauncherPreferencesController
	let isLocked: Bool
	let accentColor: Color
	@Environment(\.simulatesMissingXcode) private var simulatesMissingXcode
	@Environment(\.displayScale) private var displayScale
	@State private var isExpanded = false
	@State private var isXcodeInstalled = GamePolicyControl.isAvailable()

	private var options: GameLaunchOptions { settings.launchOptions }
	private var isGameModeAvailable: Bool { isXcodeInstalled && !simulatesMissingXcode }
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
		SettingsPanel(
			title: SettingsStrings.advancedPanel, systemImage: "gearshape.2",
			isExpanded: $isExpanded
		) {
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
			if let renderSize = plan.renderSize {
				SettingsHairline()
				SettingsActionRow(
					title: SettingsStrings.gameDraws(renderSize),
					detail: SettingsStrings.scalingDetail(plan.scaling)
				) {}
			}
			SettingsHairline()
			SettingsActionRow(
				title: SettingsStrings.gameMode,
				detail: isGameModeAvailable
					? SettingsStrings.gameModeDetail : SettingsStrings.gameModeUnavailableDetail,
				help: SettingsStrings.gameModeHelp
			) {
				SettingsToggle(
					SettingsStrings.gameMode,
					isOn: $settings.launchOptions.usesGameMode,
					accentColor: accentColor
				)
				// A saved choice stays switchable off after Xcode is removed.
				.disabled(isLocked || (!isGameModeAvailable && !options.usesGameMode))
			}
			.onAppear { isXcodeInstalled = GamePolicyControl.isAvailable() }
			SettingsHairline()
			SettingsActionRow(
				title: SettingsStrings.wineSynchronization,
				detail: SettingsStrings.wineSynchronizationDetail,
				help: SettingsStrings.wineSynchronizationHelp
			) {
				AdaptiveSegmentedControl(
					selection: $settings.launchOptions.synchronizationMode,
					options: WineSynchronizationMode.allCases,
					accentColor: accentColor,
					isDisabled: isLocked
				) { mode in
					Text(mode.displayName)
				}
			}
			SettingsHairline()
			SettingsActionRow(
				title: SettingsStrings.metalHUD,
				detail: SettingsStrings.metalHUDDetail
			) {
				SettingsToggle(
					SettingsStrings.metalHUD,
					isOn: $settings.launchOptions.usesMetalPerformanceHUD,
					accentColor: accentColor
				)
				.disabled(isLocked)
			}
		}
	}

	private var launcherDisplayControl: Binding<Bool> {
		Binding(
			get: { !settings.launchOptions.usesGameSettings },
			set: { settings.launchOptions.usesGameSettings = !$0 }
		)
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

extension EnvironmentValues {
	/// Lets the debug simulator preview Game Mode as if Xcode were not installed.
	@Entry var simulatesMissingXcode = false
}
