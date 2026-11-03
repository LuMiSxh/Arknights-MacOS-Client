// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

struct OnboardingRegionView: View {
	@Bindable var preferences: LauncherPreferencesController
	@Bindable var installation: InstallationController
	let lifecycle: LauncherLifecycleStore
	let accentColor: Color
	let canSwitchRegion: Bool
	package let selectRegion: @MainActor @Sendable (GameRegion) -> Void

	private static func regionAnswer(_ region: GameRegion) -> OnboardingAnswer<GameRegion> {
		OnboardingAnswer(
			value: region, title: region.displayName,
			detail: region == .chinaBilibili ? "For Bilibili accounts." : "", systemImage: "globe")
	}

	var body: some View {
		OnboardingPage(
			title: "Server",
			subtitle:
				"Each server has its own game files and accounts. You can add another server later in Settings.",
			accentColor: accentColor
		) {
			OnboardingQuestion(
				question: "Server",
				systemImage: "globe.asia.australia",
				answers: preferences.regionAccess.selectableRegions.map(
					Self.regionAnswer),
				selection: regionBinding,
				isDisabled: !canSwitchRegion
			)

			OnboardingCanaryPanel(title: "Canary Features") {
				OnboardingToggleRow(
					title: "Canary Features",
					detail:
						"Turns on experimental features. There are no canary features right now.",
					isOn: $preferences.canaryFeaturesEnabled,
				)
				.disabled(lifecycle.activity != .idle)
			}

			OnboardingGameFilesPanel(installation: installation, lifecycle: lifecycle)
		}
	}

	private var regionBinding: Binding<GameRegion?> {
		Binding(
			get: { installation.region },
			set: { region in
				if let region { selectRegion(region) }
			}
		)
	}
}
