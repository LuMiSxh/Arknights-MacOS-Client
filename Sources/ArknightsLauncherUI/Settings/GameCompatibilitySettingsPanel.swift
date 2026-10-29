// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

struct GameCompatibilitySettingsPanel: View {
	@Bindable var settings: LauncherPreferencesController
	let isLocked: Bool
	package let accentColor: Color
	@State private var isExpanded = false

	var body: some View {
		SettingsPanel(
			title: "Compatibility", systemImage: "wrench.and.screwdriver",
			isExpanded: $isExpanded
		) {
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
		}
	}
}
