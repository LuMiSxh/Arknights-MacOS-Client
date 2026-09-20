// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct AdaptiveSegmentedControl<Option: Hashable, Label: View>: View {
	@Binding private var selection: Option
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
	@Environment(\.isEnabled) private var environmentIsEnabled
	private let options: [Option]
	private let accentColor: Color
	private let isDisabled: Bool
	private let label: (Option) -> Label

	init(
		selection: Binding<Option>,
		options: [Option],
		accentColor: Color,
		isDisabled: Bool = false,
		@ViewBuilder label: @escaping (Option) -> Label
	) {
		_selection = selection
		self.options = options
		self.accentColor = accentColor
		self.isDisabled = isDisabled
		self.label = label
	}

	@ViewBuilder
	var body: some View {
		HStack(spacing: 4) {
			ForEach(options, id: \.self) { option in
				Button {
					selection = option
				} label: {
					HStack(spacing: 4) {
						label(option)
						if differentiateWithoutColor && selection == option {
							Image(systemName: "checkmark")
								.font(.caption2.bold())
								.accessibilityHidden(true)
						}
					}
					.font(.caption.weight(.semibold))
					.frame(maxWidth: .infinity, maxHeight: .infinity)
					.padding(.horizontal, LauncherVisuals.Control.compactHorizontalPadding)
					.padding(.vertical, LauncherVisuals.Control.compactVerticalPadding)
					.contentShape(Capsule())
				}
				.buttonStyle(ActionPressStyle())
				.keyboardFocusIndicator(in: Capsule())
				.adaptiveControlForeground(
					effectiveDisabled
						? accentColor.opacity(0.44)
						: (selection == option ? accentColor : .secondary),
					isDisabled: effectiveDisabled
				)
				.background {
					if selection == option {
						Color.clear
							.adaptiveControlSurface(
								tint: accentColor,
								isDisabled: effectiveDisabled,
								in: Capsule()
							)
					}
				}
				.accessibilityAddTraits(selection == option ? .isSelected : [])
			}
		}
		.fixedSize(horizontal: false, vertical: true)
		.padding(LauncherVisuals.Spacing.compact)
		.adaptiveControlSurface(
			tint: LauncherVisuals.controlTint,
			isDisabled: effectiveDisabled,
			in: Capsule()
		)
		.disabled(isDisabled)
		.animation(
			reduceMotion ? nil : .easeInOut(duration: LauncherVisuals.Motion.selection),
			value: selection
		)
	}

	private var effectiveDisabled: Bool {
		isDisabled || !environmentIsEnabled
	}
}
