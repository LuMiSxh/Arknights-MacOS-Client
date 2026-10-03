// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Shared press and hover feedback for custom launcher action surfaces: a critically damped
/// press, a springy release, and a small hover lift. Reduce Motion keeps only the opacity dip.
struct ActionPressStyle: ButtonStyle {
	enum Intensity {
		/// Compact buttons and pills.
		case standard
		/// Large tiles and cards, where full scaling reads as a jump.
		case subtle
		/// List rows the pointer passes over often; they only respond to a press.
		case pressOnly
	}

	var intensity = Intensity.standard

	func makeBody(configuration: Configuration) -> some View {
		ActionPressBody(configuration: configuration, intensity: intensity)
	}
}

private struct ActionPressBody: View {
	let configuration: ButtonStyleConfiguration
	let intensity: ActionPressStyle.Intensity
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.isEnabled) private var isEnabled
	@State private var isHovered = false

	var body: some View {
		configuration.label
			.opacity(isEnabled && configuration.isPressed ? 0.86 : 1)
			.scaleEffect(scale)
			.animation(pressAnimation, value: configuration.isPressed)
			.animation(
				LauncherMotion.animation(.hover, reduceMotion: reduceMotion),
				value: isHovered
			)
			.onHover { hovering in
				isHovered = hovering
			}
	}

	private var scale: CGFloat {
		guard isEnabled, !reduceMotion else { return 1 }
		switch intensity {
		case .standard:
			if configuration.isPressed { return LauncherMotion.pressedScale }
			return isHovered ? LauncherMotion.hoverScale : 1
		case .subtle:
			if configuration.isPressed { return LauncherMotion.subtlePressedScale }
			return isHovered ? LauncherMotion.subtleHoverScale : 1
		case .pressOnly:
			return configuration.isPressed ? LauncherMotion.subtlePressedScale : 1
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
						? Color.primary.opacity(0.92)
						: .clear,
					lineWidth: LauncherVisuals.Control.focusWidth
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
						? Color.primary.opacity(0.92)
						: .clear,
					lineWidth: LauncherVisuals.Control.focusWidth
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
	func keyboardFocusIndicator<S: Shape>(in shape: S) -> some View {
		modifier(KeyboardFocusIndicator(shape: shape))
	}

	func keyboardFocusIndicator<S: Shape>(isFocused: Bool, in shape: S) -> some View {
		modifier(ExplicitKeyboardFocusIndicator(isFocused: isFocused, shape: shape))
	}
}
