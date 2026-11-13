// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameRuntime
import SwiftUI

struct GamePerformanceSettingsPanel: View {
	@Bindable var settings: LauncherPreferencesController
	/// Game Mode and the Metal HUD lock while a game runs.
	let isLocked: Bool
	/// The frame rate also locks during storage migration.
	let isFrameRateLocked: Bool
	@Environment(\.simulatesMissingXcode) private var simulatesMissingXcode
	@State private var isXcodeInstalled = GamePolicyControl.isAvailable()

	private var options: GameLaunchOptions { settings.launchOptions }
	private var launcherDisplayControl: Bool { !options.usesGameSettings }
	private var isGameModeAvailable: Bool { isXcodeInstalled && !simulatesMissingXcode }

	var body: some View {
		SettingsPanel(title: "Performance") {
			SettingsActionRow(
				title: "Frame rate limit",
				detail: frameRateDetail
			) {
				AdaptiveSegmentedControl(
					selection: $settings.launchOptions.frameRateLimit,
					options: GameFrameRateLimit.allCases,
					isDisabled: isFrameRateLocked || !launcherDisplayControl
				) { limit in
					Text(limit.displayName)
				}
			}
			SettingsHairline()
			SettingsActionRow(
				title: "Game Mode",
				detail: gameModeDetail,
				help:
					"Uses Apple’s gamepolicyctl tool, which ships only inside the full Xcode app, not the Command Line Tools."
			) {
				SettingsToggle(
					"Game Mode",
					isOn: $settings.launchOptions.usesGameMode
				)
				// A saved choice stays switchable off after Xcode is removed.
				.disabled(
					isLocked || !launcherDisplayControl
						|| (!isGameModeAvailable && !options.usesGameMode))
			}
			.onAppear { isXcodeInstalled = GamePolicyControl.isAvailable() }
			SettingsHairline()
			SettingsActionRow(
				title: "Metal Performance HUD",
				detail: launcherDisplayControl
					? "Shows frame rate and GPU load in game." : overrideOffDetail
			) {
				SettingsToggle(
					"Metal Performance HUD",
					isOn: $settings.launchOptions.usesMetalPerformanceHUD
				)
				.disabled(isLocked || !launcherDisplayControl)
			}
		}
	}

	private var frameRateDetail: String {
		launcherDisplayControl
			? "Caps the frames per second the game draws. Lower limits save battery."
			: "The game keeps its own frame rate while Override in-game display settings is off. Turn it on to change this."
	}

	private var gameModeDetail: String {
		guard launcherDisplayControl else { return overrideOffDetail }
		return isGameModeAvailable
			? "Asks macOS to give the game priority while it runs. Needs the free Xcode app from the App Store."
			: "Not available on this Mac: Game Mode needs the free Xcode app from the App Store. Install it, then reopen Settings."
	}

	/// Game Mode and the Metal HUD ignore the launcher's choice while the override is off.
	private var overrideOffDetail: String {
		"The game keeps its own settings while Override in-game display settings is off. Turn it on to change this."
	}
}

extension EnvironmentValues {
	/// Lets the debug simulator preview Game Mode as if Xcode were not installed.
	@Entry var simulatesMissingXcode = false
}
