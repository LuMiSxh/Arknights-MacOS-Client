// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import SwiftUI

#if DEBUG
	struct DeveloperSettingsPage: View {
		@Environment(\.launcherTheme) private var theme
		@Binding var simulation: DeveloperSimulationState

		var body: some View {
			SettingsPage(
				title: "Developer",
				subtitle: "Preview launcher states safely"
			) {
				SettingsPanel(title: "Simulation") {
					picker("Lifecycle", \.lifecycle)
					picker("Installation phase", \.phase)
					picker("Progress", \.progress)
					picker("Transfer", \.transfer)
					picker("Server", \.selectedRegion)
					picker("Installed", \.isInstalled)
					picker("Partial download", \.hasPartialDownload)
					picker("Game update", \.updateAvailable)
					picker("Launcher update", \.launcherUpdate)
					picker("Failure", \.failure)
					picker("Support code", \.failureCode)
					picker("Runtime", \.runtime)
					picker("Canary features", \.canaryFeaturesEnabled)
					picker("Status pill", \.showStatusPill)
					picker("Version pill", \.showVersionPill)
					picker("Music pill", \.showMusicPill)
					picker("Expanded pill", \.expandedPill)
					picker("Announcement popup", \.announcement)
					picker("Dynamic theme", \.usesDynamicTheme)
					picker("Long music title", \.longAccessibilityText)
					picker("Onboarding", \.onboardingPreview)
					picker("Required onboarding", \.onboardingRequired)
					picker("Rosetta missing", \.rosettaMissing)
					picker("Xcode missing", \.xcodeMissing)
				}
				SettingsPanel(title: "Isolation") {
					Text(
						"Game actions only move between simulated states. The preview uses separate temporary paths and preferences."
					)
					.foregroundStyle(theme.textSecondary)
				}
			}
		}

		private func picker<Value: CaseIterable & Hashable>(
			_ title: String,
			_ keyPath: WritableKeyPath<DeveloperSimulationState, Value>
		) -> some View {
			picker(title, keyPath, Array(Value.allCases))
		}

		private func picker(
			_ title: String,
			_ keyPath: WritableKeyPath<DeveloperSimulationState, Bool>
		) -> some View {
			picker(title, keyPath, [false, true])
		}

		private func picker<Value: Hashable>(
			_ title: String,
			_ keyPath: WritableKeyPath<DeveloperSimulationState, Value>,
			_ choices: [Value]
		) -> some View {
			HStack {
				Text(title)
				Spacer(minLength: 0)
				GlassMenuPicker(
					selection: $simulation[dynamicMember: keyPath],
					options: choices.map { ($0, "\($0)") },
				)
			}
		}
	}
#endif
