// SPDX-License-Identifier: MPL-2.0

import SwiftUI

#if DEBUG
	struct DeveloperSettingsPage: View {
		var model: LauncherViewModel
		@State private var customPopupTitle = "Custom popup"
		@State private var customPopupMarkdown = ""

		var body: some View {
			SettingsPage(
				title: "Developer", subtitle: "Preview launcher states safely",
				accentColor: model.accentColor
			) {
				SettingsPanel(title: "Scenario", systemImage: "switch.2") {
					GlassMenuPicker(
						selection: scenarioBinding,
						options: DeveloperScenario.allCases.map { ($0, $0.title) },
						accentColor: model.accentColor
					)
					SettingsHairline()
					Text(scenarioBinding.wrappedValue.detail)
						.foregroundStyle(.secondary)
				}

				if scenarioBinding.wrappedValue == .customPopup {
					SettingsPanel(title: "Custom Popup", systemImage: "text.bubble") {
						TextField("Title", text: $customPopupTitle)
							.textFieldStyle(.roundedBorder)
						TextEditor(text: $customPopupMarkdown)
							.font(.system(.body, design: .monospaced))
							.scrollContentBackground(.hidden)
							.padding(8)
							.frame(height: 140)
							.background(.black.opacity(0.2), in: .rect(cornerRadius: 8))
						CapsuleActionButton(
							title: "Show Popup", tone: .accent(model.accentColor)
						) {
							model.applyDeveloperCustomPopup(
								title: customPopupTitle,
								markdown: customPopupMarkdown
							)
						}
						.disabled(customPopupMarkdown.isEmpty)
					}
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
