// SPDX-License-Identifier: MPL-2.0

import SwiftUI

package struct AdaptiveSegmentedControl<Option: Hashable, Label: View>: View {
	@Binding private var selection: Option
	@Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.isEnabled) private var environmentIsEnabled
	@Environment(\.launcherTheme) private var theme
	@Namespace private var thumbNamespace
	private let options: [Option]
	private let isDisabled: Bool
	private let systemImages: [String]
	private let label: (Option) -> Label

	package init(
		selection: Binding<Option>,
		options: [Option],
		isDisabled: Bool = false,
		systemImages: [String] = [],
		@ViewBuilder label: @escaping (Option) -> Label
	) {
		_selection = selection
		self.options = options
		self.isDisabled = isDisabled
		self.systemImages = systemImages
		self.label = label
	}

	@ViewBuilder
	package var body: some View {
		HStack(spacing: LauncherTokens.Spacing.compact) {
			ForEach(options.indices, id: \.self) { index in
				let option = options[index]
				let isSelected = selection == option
				Button {
					select(option)
				} label: {
					segmentContent(option, index: index)
						.font(.callout.weight(.medium))
						.foregroundStyle(isSelected ? theme.accentInk : theme.textSecondary)
						.launcherAnimation(.state, value: isSelected)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
						.padding(.horizontal, LauncherTokens.ControlPadding.segmentHorizontal)
						.padding(.vertical, LauncherTokens.ControlPadding.segmentVertical)
						.contentShape(Capsule())
				}
				.buttonStyle(SegmentPressStyle())
				.keyboardFocusIndicator(in: Capsule())
				.background {
					if isSelected {
						Color.clear
							.adaptiveGlassEffect(
								tint: theme.accentGlassTint,
								borderTint: theme.accentGlassStroke,
								in: Capsule(),
								showsBorder: true
							)
							.matchedGeometryEffect(id: "thumb", in: thumbNamespace)
					}
				}
				.accessibilityAddTraits(isSelected ? .isSelected : [])
			}
		}
		.fixedSize()
		.padding(LauncherTokens.ControlPadding.segmentTrack)
		.background { Capsule().fill(theme.trackFill) }
		.overlay { Capsule().stroke(theme.trackStroke, lineWidth: 1) }
		.disabled(isDisabled)
		.opacity(effectiveDisabled ? 0.4 : 1)
	}

	private func select(_ option: Option) {
		let fromIndex = options.firstIndex(of: selection) ?? 0
		let toIndex = options.firstIndex(of: option) ?? 0
		let animation = LauncherMotion.animation(
			for: .select, reduceMotion: reduceMotion, hops: abs(toIndex - fromIndex))
		withAnimation(animation) {
			selection = option
		}
	}

	/// Icons appear only when every option has one; otherwise the label stands alone.
	@ViewBuilder
	private func segmentContent(_ option: Option, index: Int) -> some View {
		HStack(spacing: LauncherTokens.Spacing.compact) {
			if systemImages.count == options.count {
				SwiftUI.Label {
					label(option)
				} icon: {
					Image(systemName: systemImages[index])
				}
				.labelStyle(SegmentLabelStyle())
			} else {
				label(option)
			}
			if differentiateWithoutColor && selection == option {
				Image(systemName: "checkmark")
					.font(.caption2.weight(.medium))
					.accessibilityHidden(true)
			}
		}
	}

	private var effectiveDisabled: Bool {
		isDisabled || !environmentIsEnabled
	}
}

/// Places the icon left of the title, at small image scale.
private struct SegmentLabelStyle: LabelStyle {
	func makeBody(configuration: Configuration) -> some View {
		HStack(spacing: 6) {
			configuration.icon.imageScale(.small)
			configuration.title
		}
	}
}

/// Scales only the segment label on press. The thumb stays still.
private struct SegmentPressStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.scaleEffect(configuration.isPressed ? LauncherMotion.subtlePressedScale : 1)
			.launcherAnimation(
				configuration.isPressed ? .press : .release, value: configuration.isPressed)
	}
}
