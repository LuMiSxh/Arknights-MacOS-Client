// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Shared press feedback for custom launcher action surfaces: a critically damped press and a
/// settling release. Hover feedback belongs to the surface, not to scale. Reduce Motion keeps only the opacity dip.
package struct ActionPressStyle: ButtonStyle {
	package enum Intensity {
		case standard
		/// Large tiles, cards, and action buttons, where full scaling reads as a jump.
		case subtle
		/// List rows the pointer passes over often; they only respond to a press.
		case pressOnly
	}

	var intensity = Intensity.standard

	package init(intensity: Intensity = .standard) {
		self.intensity = intensity
	}

	package func makeBody(configuration: Configuration) -> some View {
		ActionPressBody(configuration: configuration, intensity: intensity)
	}
}

private struct ActionPressBody: View {
	let configuration: ButtonStyleConfiguration
	let intensity: ActionPressStyle.Intensity
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.isEnabled) private var isEnabled

	var body: some View {
		configuration.label
			.opacity(isEnabled && configuration.isPressed ? 0.86 : 1)
			.scaleEffect(scale)
			.animation(pressAnimation, value: configuration.isPressed)
	}

	private var scale: CGFloat {
		guard isEnabled, !reduceMotion, configuration.isPressed else { return 1 }
		switch intensity {
		case .standard: return LauncherMotion.pressedScale
		case .subtle, .pressOnly: return LauncherMotion.subtlePressedScale
		}
	}

	private var pressAnimation: Animation? {
		guard isEnabled else { return nil }
		return LauncherMotion.animation(
			configuration.isPressed ? .press : .release,
			reduceMotion: reduceMotion
		)
	}
}

struct KeyboardFocusIndicator<S: Shape>: ViewModifier {
	@Environment(\.launcherTheme) private var theme
	let shape: S
	@Environment(\.settingsFocusCoordinator) private var settingsFocusCoordinator
	@Environment(\.isEnabled) private var isEnabled
	@Environment(\.appearsActive) private var appearsActive
	@FocusState private var isFocused: Bool
	@State private var focusID = UUID()

	func body(content: Content) -> some View {
		content.overlay {
			shape
				.stroke(
					isEnabled && appearsActive && isFocused
						? theme.accentFill.opacity(LauncherVisuals.focusStrokeOpacity)
						: .clear,
					lineWidth: LauncherTokens.Control.focusWidth
				)
				.padding(-3)
				.allowsHitTesting(false)
		}
		.focused($isFocused)
		.focusEffectDisabled(true)
		.id(focusID)
		.onChange(of: isFocused) { _, focused in
			guard let settingsFocusCoordinator else { return }
			if focused {
				settingsFocusCoordinator.focusedID = AnyHashable(focusID)
			} else if settingsFocusCoordinator.focusedID == AnyHashable(focusID) {
				settingsFocusCoordinator.focusedID = nil
			}
		}
	}
}

private struct ExplicitKeyboardFocusIndicator<S: Shape>: ViewModifier {
	@Environment(\.launcherTheme) private var theme
	let isFocused: Bool
	let shape: S
	@Environment(\.settingsFocusCoordinator) private var settingsFocusCoordinator
	@Environment(\.isEnabled) private var isEnabled
	@Environment(\.appearsActive) private var appearsActive
	@State private var focusID = UUID()

	func body(content: Content) -> some View {
		content.overlay {
			shape
				.stroke(
					isEnabled && appearsActive && isFocused
						? theme.accentInk.opacity(0.9)
						: .clear,
					lineWidth: LauncherTokens.Control.focusWidth
				)
				.padding(-3)
				.allowsHitTesting(false)
		}
		.id(focusID)
		.focusEffectDisabled(true)
		.onChange(of: isFocused) { _, focused in
			guard let settingsFocusCoordinator else { return }
			if focused {
				settingsFocusCoordinator.focusedID = AnyHashable(focusID)
			} else if settingsFocusCoordinator.focusedID == AnyHashable(focusID) {
				settingsFocusCoordinator.focusedID = nil
			}
		}
	}
}

extension View {
	package func keyboardFocusIndicator<S: Shape>(in shape: S) -> some View {
		modifier(KeyboardFocusIndicator(shape: shape))
	}

	package func keyboardFocusIndicator<S: Shape>(isFocused: Bool, in shape: S) -> some View {
		modifier(ExplicitKeyboardFocusIndicator(isFocused: isFocused, shape: shape))
	}
}
