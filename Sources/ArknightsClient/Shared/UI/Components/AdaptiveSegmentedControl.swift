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
				.foregroundStyle(selection == option ? accentColor : .secondary)
				.background {
					if selection == option {
						Color.clear
							.adaptiveGlassEffect(
								tint: accentColor.opacity(0.28),
								in: Capsule()
							)
							.overlay {
								Capsule().strokeBorder(accentColor.opacity(0.32))
							}
					}
				}
				.accessibilityAddTraits(selection == option ? .isSelected : [])
			}
		}
		.padding(3)
		.adaptiveGlassEffect(in: Capsule())
		.animation(
			reduceMotion ? nil : .easeInOut(duration: 0.16),
			value: selection
		)
	}
}
