// SPDX-License-Identifier: MPL-2.0

import SwiftUI

package struct SettingsToggle: View {
	let title: String
	@Binding var isOn: Bool
	/// Semantic override, such as `warning` for experimental switches.
	let tint: Color?
	@Environment(\.launcherPalette) private var palette

	package init(_ title: String, isOn: Binding<Bool>, tint: Color? = nil) {
		self.title = title
		_isOn = isOn
		self.tint = tint
	}

	package var body: some View {
		Toggle(title, isOn: $isOn)
			.labelsHidden()
			.toggleStyle(.switch)
			.controlSize(.regular)
			.tint(tint ?? palette.controlOn)
	}
}

package struct SettingsSlider: View {
	@Binding var value: Double
	let range: ClosedRange<Double>
	let step: Double
	@Environment(\.launcherPalette) private var palette
	package let width: CGFloat

	package init(
		value: Binding<Double>,
		range: ClosedRange<Double>,
		step: Double,
		width: CGFloat
	) {
		self._value = value
		self.range = range
		self.step = step
		self.width = width
	}

	package var body: some View {
		Slider(value: $value, in: range, step: step)
			.tint(palette.controlOn)
			.frame(width: width)
			.keyboardFocusIndicator(in: Capsule())
	}
}
