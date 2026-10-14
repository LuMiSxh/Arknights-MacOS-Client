// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsGameRuntime
import SwiftUI

/// Collapsed by default: who sets the display, the size the game renders, and the performance and
/// diagnostics launch options.
struct GameAdvancedSettingsPanel: View {
	@Bindable var settings: LauncherPreferencesController
	let isLocked: Bool
	package let accentColor: Color
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
			title: "Advanced", systemImage: "gearshape.2",
			isExpanded: $isExpanded
		) {
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
			if showsInGameResolutionNote {
				inGameResolutionNote
			}
			if let renderSize = plan.renderSize {
				SettingsHairline()
				SettingsActionRow(
					title: "Render resolution",
					detail: scalingDetail
				) {
					Text(renderSize.displayName)
						.monospacedDigit()
						.foregroundStyle(.secondary)
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
				title: "Wine sync (MSYNC / ESYNC)",
				detail: "MSYNC is faster on most Macs. Try ESYNC if the game freezes or crashes.",
				help:
					"Controls how Wine translates Windows thread waits. MSYNC uses macOS Mach synchronization and gave steadier frame pacing in our tests. ESYNC uses Wine's older event-based path and remains the compatibility fallback."
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
}

extension EnvironmentValues {
	/// Lets the debug simulator preview Game Mode as if Xcode were not installed.
	@Entry var simulatesMissingXcode = false
}
