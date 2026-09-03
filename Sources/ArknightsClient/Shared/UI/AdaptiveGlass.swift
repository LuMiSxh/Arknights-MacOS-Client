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
		modifier(AdaptiveGlassEffectModifier(tint: tint, shape: shape))
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
		modifier(HUDSecondaryControlSurfaceModifier(tint: tint, shape: shape))
	}
}

private struct AdaptiveGlassEffectModifier<ShapeType: Shape>: ViewModifier {
	let tint: Color?
	let shape: ShapeType
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency

	@ViewBuilder
	func body(content: Content) -> some View {
		if reduceTransparency {
			content
				.background(Color.black.opacity(0.92), in: shape)
				.overlay {
					shape
						.stroke((tint ?? Color.white).opacity(0.42), lineWidth: 1)
						.allowsHitTesting(false)
				}
		} else if #available(macOS 26, *) {
			if let tint {
				content.glassEffect(.regular.tint(tint), in: shape)
			} else {
				content.glassEffect(.regular, in: shape)
			}
		} else if let tint {
			content
				.background(tint, in: shape)
				.background(.ultraThinMaterial, in: shape)
		} else {
			content.background(.regularMaterial, in: shape)
		}
	}
}

private struct SettingsControlCapsuleModifier: ViewModifier {
	let tint: Color
	let isDisabled: Bool
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency

	private var foreground: Color {
		isDisabled ? LauncherVisuals.controlTint.opacity(0.65) : tint
	}

	private var surfaceTint: Color {
		isDisabled ? Color.white.opacity(0.05) : tint.opacity(0.13)
	}

	@ViewBuilder
	func body(content: Content) -> some View {
		if reduceTransparency {
			content
				.font(.caption.weight(.semibold))
				.foregroundStyle(foreground)
				.padding(.horizontal, 10)
				.padding(.vertical, 5)
				.background(Color.black.opacity(0.92), in: Capsule())
				.overlay {
					Capsule()
						.stroke(foreground.opacity(0.42), lineWidth: 1)
						.allowsHitTesting(false)
				}
				.contentShape(Capsule())
		} else if #available(macOS 26, *) {
			content
				.font(.caption.weight(.semibold))
				.foregroundStyle(foreground)
				.padding(.horizontal, 10)
				.padding(.vertical, 5)
				.glassEffect(.regular.tint(surfaceTint), in: .capsule)
				.contentShape(Capsule())
		} else {
			content
				.font(.caption.weight(.semibold))
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

private struct HUDSecondaryControlSurfaceModifier<ShapeType: InsettableShape>: ViewModifier {
	let tint: Color
	let shape: ShapeType
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency

	func body(content: Content) -> some View {
		content
			.foregroundStyle(tint)
			.background(
				reduceTransparency ? Color.black.opacity(0.92) : tint.opacity(0.12),
				in: shape
			)
			.overlay {
				shape
					.strokeBorder(
						reduceTransparency ? tint.opacity(0.42) : tint.opacity(0.18)
					)
					.allowsHitTesting(false)
			}
	}
}

extension View {
	/// Shared compact chrome for Settings actions and menu pickers.
	func settingsControlCapsule(tint: Color, isDisabled: Bool = false) -> some View {
		modifier(SettingsControlCapsuleModifier(tint: tint, isDisabled: isDisabled))
	}
}
