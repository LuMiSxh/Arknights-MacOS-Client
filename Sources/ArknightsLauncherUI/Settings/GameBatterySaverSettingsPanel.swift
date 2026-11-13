// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct GameBatterySaverSettingsPanel: View {
	@Bindable var settings: LauncherPreferencesController
	/// Battery Saver locks while a game runs.
	let isLocked: Bool

	private var usesOverride: Bool { !settings.launchOptions.usesGameSettings }

	var body: some View {
		SettingsPanel(title: "Battery Saver") {
			SettingsActionRow(
				title: "Battery Saver mode",
				detail:
					"Applies whenever it is on. Caps the frame rate, turns off Game Mode, and lowers Rendering when the override is on."
			) {
				SettingsToggle(
					"Battery Saver mode",
					isOn: $settings.batterySaverEnabled
				)
				.disabled(isLocked)
			}
			if settings.batterySaverEnabled {
				SettingsHairline()
				SettingsActionRow(
					title: "Battery Saver frame rate limit",
					detail: frameRateLimitDetail
				) {
					AdaptiveSegmentedControl(
						selection: $settings.batterySaverFrameRateLimit,
						options: GameFrameRateLimit.batterySaverChoices,
						isDisabled: isLocked
					) { limit in
						Text(limit.displayName)
					}
				}
			}
		}
	}

	private var frameRateLimitDetail: String {
		usesOverride
			? "Caps the frame rate at this limit or at Frame rate limit, whichever is lower."
			: "Caps the frame rate at this limit. Frame rate limit does not apply while the override is off."
	}
}
