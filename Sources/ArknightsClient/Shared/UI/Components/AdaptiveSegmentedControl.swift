// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct AdaptiveSegmentedControl<Option: Hashable, Label: View>: View {
	@Binding private var selection: Option
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	private let options: [Option]
	private let accentColor: Color
	private let label: (Option) -> Label

	init(
		selection: Binding<Option>,
		options: [Option],
		accentColor: Color,
		@ViewBuilder label: @escaping (Option) -> Label
	) {
		_selection = selection
		self.options = options
		self.accentColor = accentColor
		self.label = label
	}

	@ViewBuilder
	var body: some View {
		if #available(macOS 26, *) {
			HStack(spacing: 4) {
				ForEach(options, id: \.self) { option in
					Button {
						selection = option
					} label: {
						label(option)
							.font(.caption.weight(.semibold))
							.frame(maxWidth: .infinity)
							.padding(.horizontal, 10)
							.padding(.vertical, 5)
							.contentShape(Capsule())
					}
					.buttonStyle(.plain)
					.background {
						if selection == option {
							Color.clear.glassEffect(
								.regular.tint(accentColor.opacity(0.42)),
								in: Capsule()
							)
						}
					}
					.accessibilityAddTraits(selection == option ? .isSelected : [])
				}
			}
			.padding(3)
			.glassEffect(.regular, in: Capsule())
			.animation(
				reduceMotion ? nil : .easeInOut(duration: 0.16),
				value: selection
			)
		} else {
			Picker("", selection: $selection) {
				ForEach(options, id: \.self) { option in
					label(option).tag(option)
				}
			}
			.labelsHidden()
			.pickerStyle(.segmented)
			.tint(accentColor)
			.animation(
				reduceMotion ? nil : .easeInOut(duration: 0.16),
				value: selection
			)
		}
	}
}
