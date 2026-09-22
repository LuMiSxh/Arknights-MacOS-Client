// SPDX-License-Identifier: MPL-2.0

import SwiftUI

/// Shared native-feeling press feedback for custom launcher action surfaces.
struct ActionPressStyle: ButtonStyle {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.isEnabled) private var isEnabled

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.opacity(isEnabled && configuration.isPressed ? 0.86 : 1)
			.scaleEffect(
				reduceMotion || !isEnabled ? 1 : (configuration.isPressed ? 0.98 : 1)
			)
			.animation(
				reduceMotion || !isEnabled
					? nil
					: .easeOut(duration: LauncherVisuals.Motion.control),
				value: configuration.isPressed
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
