// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Launch options that tune or measure how smoothly the game runs.
struct GamePerformanceSettingsPanel: View {
	@Bindable var settings: LauncherPreferencesController
	let isLocked: Bool
	let accentColor: Color
	@Environment(\.simulatesMissingXcode) private var simulatesMissingXcode
	@State private var isXcodeInstalled = GamePolicyControl.isAvailable()

	private var isGameModeAvailable: Bool { isXcodeInstalled && !simulatesMissingXcode }

	var body: some View {
		SettingsPanel(
			title: SettingsStrings.performance, systemImage: "gauge.with.dots.needle.67percent"
		) {
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
				.disabled(
					isLocked || (!isGameModeAvailable && !settings.launchOptions.usesGameMode))
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
}

extension EnvironmentValues {
	/// Lets the debug simulator preview Game Mode as if Xcode were not installed.
	@Entry var simulatesMissingXcode = false
}
