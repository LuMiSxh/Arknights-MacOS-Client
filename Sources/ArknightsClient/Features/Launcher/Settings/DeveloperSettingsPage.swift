// SPDX-License-Identifier: MPL-2.0

import SwiftUI

#if DEBUG
	struct DeveloperSettingsPage: View {
		@Binding var scenario: DeveloperScenario
		let accentColor: Color
		let applyCustomPopup: (String, String) -> Void
		@State private var customPopupTitle = SettingsStrings.developerCustomPopup
		@State private var customPopupMarkdown = ""

		var body: some View {
			SettingsPage(
				title: SettingsStrings.developerTitle,
				subtitle: SettingsStrings.developerSubtitle,
				accentColor: accentColor
			) {
				SettingsPanel(
					title: SettingsStrings.developerScenario, systemImage: "switch.2"
				) {
					GlassMenuPicker(
						selection: $scenario,
						options: DeveloperScenario.allCases.map { ($0, $0.title) },
						accentColor: accentColor
					)
					SettingsHairline()
					Text(scenario.detail)
						.foregroundStyle(.secondary)
				}

				if scenario == .customPopup {
					SettingsPanel(
						title: SettingsStrings.developerCustomPopup,
						systemImage: "text.bubble"
					) {
						TextField(
							SettingsStrings.developerCustomPopupTitle,
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
							title: SettingsStrings.developerShowPopup,
							tone: .accent(accentColor)
						) {
							applyCustomPopup(customPopupTitle, customPopupMarkdown)
						}
						.disabled(customPopupMarkdown.isEmpty)
					}
				}

				SettingsPanel(
					title: SettingsStrings.developerIsolation,
					systemImage: "lock.shield"
				) {
					Text(SettingsStrings.developerIsolationDetail)
						.foregroundStyle(.secondary)
				}
			}
		}
	}
#endif
