// SPDX-License-Identifier: MPL-2.0

import SwiftUI

package struct SettingsToggle: View {
	let title: String
	@Binding var isOn: Bool
	let accentColor: Color

	package init(_ title: String, isOn: Binding<Bool>, accentColor: Color) {
		self.title = title
		_isOn = isOn
		self.accentColor = accentColor
	}

	package var body: some View {
		Toggle(title, isOn: $isOn)
			.labelsHidden()
			.toggleStyle(.switch)
			.controlSize(.regular)
			.tint(accentColor)
	}
}

package struct SettingsSlider: View {
	@Binding var value: Double
	let range: ClosedRange<Double>
	let step: Double
	let accentColor: Color
	let width: CGFloat

	package init(
		value: Binding<Double>,
		range: ClosedRange<Double>,
		step: Double,
		accentColor: Color,
		width: CGFloat
	) {
		self._value = value
		self.range = range
		self.step = step
		self.accentColor = accentColor
		self.width = width
	}

	package var body: some View {
		Slider(value: $value, in: range, step: step)
			.tint(accentColor)
			.frame(width: width)
			.keyboardFocusIndicator(in: Capsule())
	}
}
