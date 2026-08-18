// SPDX-License-Identifier: MPL-2.0

import SwiftUI

#if DEBUG
	struct DeveloperSettingsPage: View {
		var model: LauncherViewModel

		var body: some View {
			SettingsPage(title: "Developer", subtitle: "Preview launcher states safely") {
				SettingsPanel(title: "Scenario", systemImage: "switch.2") {
					Picker("State", selection: scenarioBinding) {
						ForEach(DeveloperScenario.allCases) { scenario in
							Text(scenario.title).tag(scenario)
						}
					}
					.pickerStyle(.menu)
					SettingsHairline()
					Text(scenarioBinding.wrappedValue.detail)
						.foregroundStyle(.secondary)
				}

				SettingsPanel(title: "Isolation", systemImage: "lock.shield") {
					Text(
						"Game actions only move between simulated states. The preview uses separate temporary paths and preferences."
					)
					.foregroundStyle(.secondary)
				}
			}
		}

		private var scenarioBinding: Binding<DeveloperScenario> {
			Binding(
				get: { model.developerScenario ?? .ready },
				set: { scenario in model.applyDeveloperScenario(scenario) }
			)
		}
	}
#endif
