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
	package let accentColor: Color
	@Environment(\.simulatesMissingXcode) private var simulatesMissingXcode
	@State private var isXcodeInstalled = GamePolicyControl.isAvailable()

	private var options: GameLaunchOptions { settings.launchOptions }
	private var isGameModeAvailable: Bool { isXcodeInstalled && !simulatesMissingXcode }

	var body: some View {
		SettingsPanel(title: "Performance", systemImage: "speedometer") {
			SettingsActionRow(
				title: "Frame rate limit",
				help: "Lower limits save battery. Applies on next launch."
			) {
				HStack(spacing: 8) {
					SettingsSlider(
						value: frameRateStep,
						range: 0...Double(GameFrameRateLimit.allCases.count - 1),
						step: 1,
						accentColor: accentColor,
						width: 140
					)
					.disabled(isFrameRateLocked)
					.accessibilityLabel("Frame rate limit")
					.accessibilityValue(options.frameRateLimit.displayName)
					Text(options.frameRateLimit.displayName)
						.font(.caption.monospacedDigit())
						.foregroundStyle(.secondary)
						.frame(width: 72, alignment: .trailing)
						.accessibilityHidden(true)
				}
			}
			SettingsHairline()
			SettingsActionRow(
				title: "Game Mode",
				detail: isGameModeAvailable
					? "Asks macOS to give the game priority while it runs. Needs the free Xcode app from the App Store."
					: "Not available on this Mac: Game Mode needs the free Xcode app from the App Store. Install it, then reopen Settings.",
				help:
					"Uses Apple's gamepolicyctl tool, which ships only inside the full Xcode app, not the Command Line Tools."
			) {
				SettingsToggle(
					"Game Mode",
					isOn: $settings.launchOptions.usesGameMode,
					accentColor: accentColor
				)
				// A saved choice stays switchable off after Xcode is removed.
				.disabled(isLocked || (!isGameModeAvailable && !options.usesGameMode))
			}
			.onAppear { isXcodeInstalled = GamePolicyControl.isAvailable() }
			SettingsHairline()
			SettingsActionRow(
				title: "Metal Performance HUD",
				detail: "Shows frame rate and GPU load in game."
			) {
				SettingsToggle(
					"Metal Performance HUD",
					isOn: $settings.launchOptions.usesMetalPerformanceHUD,
					accentColor: accentColor
				)
				.disabled(isLocked)
			}
		}
	}

	/// Maps the slider's stop index to a frame rate limit, in `allCases` order.
	private var frameRateStep: Binding<Double> {
		let limits = GameFrameRateLimit.allCases
		return Binding(
			get: { Double(limits.firstIndex(of: options.frameRateLimit) ?? 0) },
			set: { settings.launchOptions.frameRateLimit = limits[Int($0.rounded())] }
		)
	}
}

extension EnvironmentValues {
	/// Lets the debug simulator preview Game Mode as if Xcode were not installed.
	@Entry var simulatesMissingXcode = false
}
