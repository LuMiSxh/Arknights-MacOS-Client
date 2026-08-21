// SPDX-License-Identifier: MPL-2.0

import SwiftUI

extension View {
	/// Applies Liquid Glass on macOS 26 and newer; on macOS 15–25, layers a translucent
	/// material fill behind the content instead, since `glassEffect` isn't available there.
	@ViewBuilder
	func adaptiveGlassEffect(
		tint: Color? = nil,
		in shape: some Shape = Rectangle()
	) -> some View {
		if #available(macOS 26, *) {
			if let tint {
				self.glassEffect(.regular.tint(tint), in: shape)
			} else {
				self.glassEffect(.regular, in: shape)
			}
		} else {
			if let tint {
				self.background(tint, in: shape)
					.background(.ultraThinMaterial, in: shape)
			} else {
				self.background(.regularMaterial, in: shape)
			}
		}
	}

	/// Applies neutral Liquid Glass to compact icon controls, with a bordered fallback.
	@ViewBuilder
	func adaptiveGlassButton() -> some View {
		if #available(macOS 26, *) {
			self.buttonStyle(.glass)
		} else {
			self.buttonStyle(.bordered)
		}
	}

	/// Applies the shared accent action treatment independently of control geometry.
	func adaptiveActionSurface<ControlShape: InsettableShape>(
		tint: Color,
		in shape: ControlShape
	) -> some View {
		self.foregroundStyle(tint)
			.adaptiveGlassEffect(tint: tint.opacity(0.1), in: shape)
			.overlay {
				shape.strokeBorder(tint.opacity(0.2)).allowsHitTesting(false)
			}
	}

	/// Keeps Back and Skip visually separate from actions that mutate launcher state.
	func adaptiveNavigationCapsuleButton() -> some View {
		self.buttonBorderShape(.capsule)
			.buttonStyle(.bordered)
			.tint(LauncherVisuals.controlTint)
	}

	/// Gives compact HUD controls one neutral surface instead of ad-hoc white overlays.
	func hudSecondaryControlSurface<ControlShape: InsettableShape>(
		tint: Color = LauncherVisuals.controlTint,
		in shape: ControlShape
	) -> some View {
		self.foregroundStyle(tint)
			.background(tint.opacity(0.12), in: shape)
			.overlay {
				shape.strokeBorder(tint.opacity(0.18)).allowsHitTesting(false)
			}
	}
}

private struct SettingsControlCapsuleModifier: ViewModifier {
	let tint: Color
	let isDisabled: Bool

	private var foreground: Color {
		isDisabled ? LauncherVisuals.controlTint.opacity(0.65) : tint
	}

	private var surfaceTint: Color {
		isDisabled ? Color.white.opacity(0.05) : tint.opacity(0.13)
	}

	@ViewBuilder
	func body(content: Content) -> some View {
		if #available(macOS 26, *) {
			content
				.font(.system(size: 12, weight: .semibold))
				.foregroundStyle(foreground)
				.padding(.horizontal, 10)
				.padding(.vertical, 5)
				.glassEffect(.regular.tint(surfaceTint), in: .capsule)
				.contentShape(Capsule())
		} else {
			content
				.font(.system(size: 12, weight: .semibold))
				.foregroundStyle(foreground)
				.padding(.horizontal, 10)
				.padding(.vertical, 5)
				.background(surfaceTint, in: Capsule())
				.background(.ultraThinMaterial, in: Capsule())
				.overlay {
					Capsule().strokeBorder(foreground.opacity(0.18))
				}
				.contentShape(Capsule())
		}
	}
}

extension View {
	/// Shared compact chrome for Settings actions and menu pickers.
	func settingsControlCapsule(tint: Color, isDisabled: Bool = false) -> some View {
		modifier(SettingsControlCapsuleModifier(tint: tint, isDisabled: isDisabled))
	}
}
