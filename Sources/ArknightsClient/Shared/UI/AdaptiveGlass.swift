// SPDX-License-Identifier: MPL-2.0

import SwiftUI

extension View {
	/// Applies Liquid Glass on macOS 26 and newer; on macOS 15–25, layers a translucent
	/// material fill behind the content instead, since `glassEffect` isn't available there.
	@ViewBuilder
	func adaptiveGlassEffect(
		tint: Color? = nil,
		in shape: some Shape = Rectangle(),
		showsBorder: Bool = false
	) -> some View {
		modifier(
			AdaptiveGlassEffectModifier(
				tint: tint,
				shape: shape,
				showsBorder: showsBorder
			)
		)
	}

	/// Keeps a chromatic foreground readable on macOS 27 while preserving the same hue.
	@ViewBuilder
	func adaptiveTintForeground(_ tint: Color) -> some View {
		if #available(macOS 27, *) {
			foregroundStyle(LauncherVisuals.contrastTint(tint))
		} else {
			foregroundStyle(tint)
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
		foreground: Color? = nil,
		in shape: ControlShape
	) -> some View {
		self.adaptiveTintForeground(foreground ?? tint)
			.adaptiveGlassEffect(tint: tint.opacity(0.1), in: shape, showsBorder: true)
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

enum AdaptiveGlassSurfaceTreatment: Equatable {
	private static let macOS27MinimumTintOpacity = 0.24
	static let macOS27BackplateOpacity = 0.68
	static let macOS27ChromaticBackplateOpacity = 0.44

	case reducedTransparency(showBorders: Bool)
	case macOS27(showBorders: Bool, hasTint: Bool)
	case macOS26
	case material

	static func resolve(
		isMacOS27Available: Bool,
		isMacOS26Available: Bool,
		reduceTransparency: Bool,
		showBorders: Bool,
		hasTint: Bool
	) -> Self {
		if reduceTransparency {
			.reducedTransparency(showBorders: showBorders)
		} else if isMacOS27Available {
			.macOS27(showBorders: showBorders, hasTint: hasTint)
		} else if isMacOS26Available {
			.macOS26
		} else {
			.material
		}
	}

	static func macOS27TintOpacity(for opacity: Double) -> Double {
		max(macOS27MinimumTintOpacity, min(opacity, 1))
	}
}

private struct AdaptiveGlassEffectModifier<ShapeType: Shape>: ViewModifier {
	let tint: Color?
	let shape: ShapeType
	let showsBorder: Bool
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
	@Environment(\.accessibilityShowBorders) private var showBorders

	@ViewBuilder
	func body(content: Content) -> some View {
		switch AdaptiveGlassSurfaceTreatment.resolve(
			isMacOS27Available: isMacOS27Available,
			isMacOS26Available: isMacOS26Available,
			reduceTransparency: reduceTransparency,
			showBorders: showBorders || showsBorder,
			hasTint: tint != nil
		) {
		case .reducedTransparency(let showBorders):
			content
				.background(Color.black.opacity(0.92), in: shape)
				.overlay {
					shape
						.stroke(
							(tint ?? Color.white).opacity(showBorders ? 0.68 : 0.42),
							lineWidth: 1
						)
						.allowsHitTesting(false)
				}
		case .macOS27(let showBorders, let hasTint):
			if #available(macOS 26, *) {
				macOS27Glass(content, showBorders: showBorders, hasTint: hasTint)
			}
		case .macOS26:
			if #available(macOS 26, *) {
				macOS26Glass(content)
			}
		case .material:
			macOS15To25Material(content)
		}
	}

	private var isMacOS27Available: Bool {
		if #available(macOS 27, *) {
			true
		} else {
			false
		}
	}

	private var isMacOS26Available: Bool {
		if #available(macOS 26, *) {
			true
		} else {
			false
		}
	}

	@available(macOS 26, *)
	@ViewBuilder
	private func macOS27Glass(
		_ content: Content,
		showBorders: Bool,
		hasTint: Bool
	) -> some View {
		if showBorders {
			macOS27GlassContent(content, hasTint: hasTint)
				.overlay {
					shape
						.stroke(
							macOS27BorderTint.opacity(0.72),
							lineWidth: 1
						)
						.allowsHitTesting(false)
				}
		} else {
			macOS27GlassContent(content, hasTint: hasTint)
		}
	}

	@available(macOS 26, *)
	@ViewBuilder
	private func macOS27GlassContent(_ content: Content, hasTint: Bool) -> some View {
		if hasTint, let tint = macOS27ColorTint {
			macOS27Backplate(content, tint: tint)
				.glassEffect(
					.regular.tint(tint),
					in: shape
				)
		} else {
			macOS27Backplate(content, tint: nil)
				.glassEffect(.regular, in: shape)
		}
	}

	@ViewBuilder
	private func macOS27Backplate(_ content: Content, tint: Color?) -> some View {
		if let tint {
			content
				.background(tint, in: shape)
				.background(
					Color.black.opacity(
						AdaptiveGlassSurfaceTreatment.macOS27ChromaticBackplateOpacity
					),
					in: shape
				)
		} else {
			content.background(
				Color.black.opacity(AdaptiveGlassSurfaceTreatment.macOS27BackplateOpacity),
				in: shape
			)
		}
	}

	// Keep high-chroma accents visible on macOS 27, while near-neutral HUD tints use
	// the darker neutral backplate. The chroma test also avoids turning a black tint blue.
	private var macOS27ColorTint: Color? {
		guard let tint else { return nil }
		let resolved = tint.resolve(in: EnvironmentValues())
		let chroma =
			max(resolved.red, resolved.green, resolved.blue)
			- min(resolved.red, resolved.green, resolved.blue)
		guard chroma > 0.08 else { return nil }
		return Color(
			.sRGB,
			red: Double(resolved.red),
			green: Double(resolved.green),
			blue: Double(resolved.blue),
			opacity: AdaptiveGlassSurfaceTreatment.macOS27TintOpacity(
				for: Double(resolved.opacity)
			)
		)
	}

	private var macOS27BorderTint: Color {
		guard let tint else { return .white }
		let resolved = tint.resolve(in: EnvironmentValues())
		let red = Double(resolved.red)
		let green = Double(resolved.green)
		let blue = Double(resolved.blue)
		let chroma = max(red, green, blue) - min(red, green, blue)
		guard chroma > 0.08 else { return LauncherVisuals.macOS27NeutralControlTint }
		return Color(.sRGB, red: red, green: green, blue: blue)
	}

	@available(macOS 26, *)
	@ViewBuilder
	private func macOS26Glass(_ content: Content) -> some View {
		if let tint {
			content.glassEffect(.regular.tint(tint), in: shape)
		} else {
			content.glassEffect(.regular, in: shape)
		}
	}

	@ViewBuilder
	private func macOS15To25Material(_ content: Content) -> some View {
		if let tint {
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

	private var foreground: Color {
		isDisabled ? LauncherVisuals.controlTint.opacity(0.65) : tint
	}

	private var surfaceTint: Color {
		isDisabled ? Color.white.opacity(0.05) : tint.opacity(0.13)
	}

	func body(content: Content) -> some View {
		content
			.font(.caption.weight(.semibold))
			.adaptiveTintForeground(foreground)
			.padding(.horizontal, 10)
			.padding(.vertical, 5)
			.adaptiveGlassEffect(tint: surfaceTint, in: Capsule(), showsBorder: true)
			.contentShape(Capsule())
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
