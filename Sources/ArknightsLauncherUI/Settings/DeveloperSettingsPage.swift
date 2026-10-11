// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import SwiftUI

#if DEBUG
	struct DeveloperSettingsPage: View {
		@Binding var simulation: DeveloperSimulationState
		let accentColor: Color
		let applyCustomPopup: (String, String) -> Void
		var body: some View {
			SettingsPage(
				title: "Developer",
				subtitle: "Preview launcher states safely",
				accentColor: accentColor
			) {
				DeveloperSimulationControls(
					simulation: $simulation,
					accentColor: accentColor
				)

				if simulation.popup == .custom {
					SettingsPanel(
						title: "Custom Popup",
						systemImage: "text.bubble"
					) {
						TextField(
							"Title",
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
							title: "Show Popup",
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
					title: "Isolation",
					systemImage: "lock.shield"
				) {
					Text(
						"Game actions only move between simulated states. The preview uses separate temporary paths and preferences."
					)
					.foregroundStyle(.secondary)
				}
			}
		}
	}
#endif
