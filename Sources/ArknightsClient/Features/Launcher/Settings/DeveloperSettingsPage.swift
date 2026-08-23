// SPDX-License-Identifier: MPL-2.0

import SwiftUI

#if DEBUG
	struct DeveloperSettingsPage: View {
		var model: LauncherViewModel
		@State private var customPopupTitle = L10n.string(SettingsStrings.developerCustomPopup)
		@State private var customPopupMarkdown = ""

		var body: some View {
			SettingsPage(
				title: L10n.string(SettingsStrings.developerTitle),
				subtitle: L10n.string(SettingsStrings.developerSubtitle),
				accentColor: model.accentColor
			) {
				SettingsPanel(
					title: L10n.string(SettingsStrings.developerScenario), systemImage: "switch.2"
				) {
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
					SettingsPanel(
						title: L10n.string(SettingsStrings.developerCustomPopup),
						systemImage: "text.bubble"
					) {
						TextField(
							L10n.string(SettingsStrings.developerCustomPopupTitle),
							text: $customPopupTitle
						)
						.textFieldStyle(.roundedBorder)
						TextEditor(text: $customPopupMarkdown)
							.font(.system(.body, design: .monospaced))
							.scrollContentBackground(.hidden)
							.padding(8)
							.frame(height: 140)
							.background(.black.opacity(0.2), in: .rect(cornerRadius: 8))
						CapsuleActionButton(
							title: L10n.string(SettingsStrings.developerShowPopup),
							tone: .accent(model.accentColor)
						) {
							model.applyDeveloperCustomPopup(
								title: customPopupTitle,
								markdown: customPopupMarkdown
							)
						}
						.disabled(customPopupMarkdown.isEmpty)
					}
				}

				SettingsPanel(
					title: L10n.string(SettingsStrings.developerIsolation),
					systemImage: "lock.shield"
				) {
					Text(
						SettingsStrings.developerIsolationDetail
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
