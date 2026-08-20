// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Adds the plain-language consequence that Settings tooltips cannot teach during setup.
struct OnboardingToggleRow: View {
	let title: String
	let detail: String
	@Binding var isOn: Bool
	let accentColor: Color

	var body: some View {
		HStack(alignment: .top, spacing: 18) {
			VStack(alignment: .leading, spacing: 3) {
				Text(title)
				Text(detail)
					.font(.caption)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
			Spacer(minLength: 18)
			Toggle(title, isOn: $isOn)
				.labelsHidden()
				.toggleStyle(.switch)
				.tint(accentColor)
		}
	}
}
