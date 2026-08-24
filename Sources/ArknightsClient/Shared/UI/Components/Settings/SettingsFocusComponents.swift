// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct SettingsToggle: View {
	let title: String
	@Binding var isOn: Bool
	let accentColor: Color

	init(_ title: String, isOn: Binding<Bool>, accentColor: Color) {
		self.title = title
		_isOn = isOn
		self.accentColor = accentColor
	}

	var body: some View {
		Toggle(title, isOn: $isOn)
			.labelsHidden()
			.toggleStyle(.switch)
			.tint(accentColor)
			.keyboardFocusIndicator(in: Capsule())
	}
}

struct SettingsSlider: View {
	@Binding var value: Double
	let range: ClosedRange<Double>
	let step: Double
	let accentColor: Color
	let width: CGFloat

	var body: some View {
		Slider(value: $value, in: range, step: step)
			.tint(accentColor)
			.frame(width: width)
			.keyboardFocusIndicator(in: Capsule())
	}
}
