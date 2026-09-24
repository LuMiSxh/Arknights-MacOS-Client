// SPDX-License-Identifier: MPL-2.0

import SwiftUI

#if DEBUG
	struct DeveloperSettingsPage: View {
		@Binding var simulation: DeveloperSimulationState
		let accentColor: Color
		let applyCustomPopup: (String, String) -> Void
		@State private var isComponentLabPresented = false

		var body: some View {
			SettingsPage(
				title: SettingsStrings.developerTitle,
				subtitle: SettingsStrings.developerSubtitle,
				accentColor: accentColor
			) {
				DeveloperSimulationControls(
					simulation: $simulation,
					accentColor: accentColor
				)

				if simulation.popup == .custom {
					SettingsPanel(
						title: SettingsStrings.developerCustomPopup,
						systemImage: "text.bubble"
					) {
						TextField(
							SettingsStrings.developerCustomPopupTitle,
							text: $simulation.customPopupTitle
						)
						.textFieldStyle(.roundedBorder)
						TextEditor(text: $simulation.customPopupMarkdown)
							.font(.system(.body, design: .monospaced))
							.scrollContentBackground(.hidden)
							.padding(8)
							.frame(height: 140)
							.background(.black.opacity(0.2), in: .rect(cornerRadius: 8))
						CapsuleActionButton(
							title: SettingsStrings.developerShowPopup,
							tone: .accent(accentColor)
						) {
							applyCustomPopup(
								simulation.customPopupTitle,
								simulation.customPopupMarkdown
							)
						}
						.disabled(simulation.customPopupMarkdown.isEmpty)
					}
				}

				SettingsPanel(
					title: SettingsStrings.developerIsolation,
					systemImage: "lock.shield"
				) {
					Text(SettingsStrings.developerIsolationDetail)
						.foregroundStyle(.secondary)
				}

				SettingsPanel(
					title: "Temporary Component Design Lab",
					systemImage: "testtube.2"
				) {
					Text(
						"Compare the shared control states, surfaces, and spacing used by the launcher."
					)
					.foregroundStyle(.secondary)
					CapsuleActionButton(
						title: "Open Component Lab",
						systemImage: "rectangle.3.group",
						tone: .neutral,
						presentation: .compact
					) {
						isComponentLabPresented = true
					}
				}
			}
			.sheet(isPresented: $isComponentLabPresented) {
				DeveloperComponentLabPage(accentColor: accentColor)
			}
		}
	}
#endif
