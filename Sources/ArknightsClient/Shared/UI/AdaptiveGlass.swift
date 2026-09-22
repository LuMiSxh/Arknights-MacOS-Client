// SPDX-License-Identifier: MPL-2.0

import SwiftUI

extension View {
	/// Applies Liquid Glass on macOS 26 and newer; on macOS 15–25, layers a translucent
	/// material fill behind the content instead, since `glassEffect` isn't available there.
	@ViewBuilder
	func adaptiveGlassEffect(
		tint: Color? = nil,
		borderTint: Color? = nil,
		in shape: some Shape = Rectangle(),
		showsBorder: Bool = false,
		isInteractive: Bool = false
	) -> some View {
		modifier(
			AdaptiveGlassEffectModifier(
				tint: tint,
				borderTint: borderTint,
				shape: shape,
				showsBorder: showsBorder,
				isInteractive: isInteractive
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

}

enum AdaptiveGlassBorderTintSource: Equatable {
	case semanticEdge
	case surface
	case neutral
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

	/// Returns whether a caller must draw its semantic edge outside the adaptive surface.
	/// macOS 27 Glass owns the accessibility border; older fallbacks and the ordinary
	/// presentation leave the semantic edge to the caller. Reduced transparency always
	/// draws its own accessibility edge.
	static func ownsExternalBorder(
		reduceTransparency: Bool,
		showBorders: Bool
	) -> Bool {
		borderOwner(
			isMacOS27Available: isMacOS27Available,
			isMacOS26Available: isMacOS26Available,
			reduceTransparency: reduceTransparency,
			showBorders: showBorders
		) == .external
	}

	static func ownsExternalBorder(
		isMacOS27Available: Bool,
		reduceTransparency: Bool,
		showBorders: Bool
	) -> Bool {
		borderOwner(
			isMacOS27Available: isMacOS27Available,
			isMacOS26Available: false,
			reduceTransparency: reduceTransparency,
			showBorders: showBorders
		) == .external
	}

	static func borderOwner(
		isMacOS27Available: Bool,
		isMacOS26Available: Bool,
		reduceTransparency: Bool,
		showBorders: Bool
	) -> AdaptiveGlassBorderOwner {
		switch resolve(
			isMacOS27Available: isMacOS27Available,
			isMacOS26Available: isMacOS26Available,
			reduceTransparency: reduceTransparency,
			showBorders: showBorders,
			hasTint: false
		) {
		case .reducedTransparency:
			.adaptiveSurface
		case .macOS27(let showBorders, _):
			showBorders ? .adaptiveSurface : .external
		case .macOS26, .material:
			.external
		}
	}

	static func borderTintSource(
		hasSemanticEdgeTint: Bool,
		hasSurfaceTint: Bool
	) -> AdaptiveGlassBorderTintSource {
		if hasSemanticEdgeTint {
			.semanticEdge
		} else if hasSurfaceTint {
			.surface
		} else {
			.neutral
		}
	}

	private static var isMacOS27Available: Bool {
		if #available(macOS 27, *) { return true }
		return false
	}

	private static var isMacOS26Available: Bool {
		if #available(macOS 26, *) { return true }
		return false
	}
}

enum AdaptiveGlassBorderOwner: Equatable {
	case adaptiveSurface
	case external
}

private struct AdaptiveGlassEffectModifier<ShapeType: Shape>: ViewModifier {
	let tint: Color?
	let borderTint: Color?
	let shape: ShapeType
	let showsBorder: Bool
	let isInteractive: Bool
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
	@Environment(\.accessibilityShowBorders) private var showBorders
	@Environment(\.isEnabled) private var isEnabled

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
							(effectiveBorderTint ?? Color.white).opacity(
								showBorders ? 0.68 : 0.42
							),
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
			if isInteractive {
				macOS27Backplate(content, tint: tint)
					.glassEffect(.regular.tint(tint).interactive(isEnabled), in: shape)
			} else {
				macOS27Backplate(content, tint: tint)
					.glassEffect(.regular.tint(tint), in: shape)
			}
		} else {
			if isInteractive {
				macOS27Backplate(content, tint: nil)
					.glassEffect(.regular.interactive(isEnabled), in: shape)
			} else {
				macOS27Backplate(content, tint: nil)
					.glassEffect(.regular, in: shape)
			}
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
		guard let tint = effectiveBorderTint else { return .white }
		let resolved = tint.resolve(in: EnvironmentValues())
		let red = Double(resolved.red)
		let green = Double(resolved.green)
		let blue = Double(resolved.blue)
		let chroma = max(red, green, blue) - min(red, green, blue)
		guard chroma > 0.08 else { return LauncherVisuals.macOS27NeutralControlTint }
		return Color(.sRGB, red: red, green: green, blue: blue)
	}

	private var effectiveBorderTint: Color? {
		switch AdaptiveGlassSurfaceTreatment.borderTintSource(
			hasSemanticEdgeTint: borderTint != nil,
			hasSurfaceTint: tint != nil
		) {
		case .semanticEdge:
			borderTint
		case .surface:
			tint
		case .neutral:
			nil
		}
	}

	@available(macOS 26, *)
	@ViewBuilder
	private func macOS26Glass(_ content: Content) -> some View {
		if let tint {
			if isInteractive {
				content.glassEffect(.regular.tint(tint).interactive(isEnabled), in: shape)
			} else {
				content.glassEffect(.regular.tint(tint), in: shape)
			}
		} else {
			if isInteractive {
				content.glassEffect(.regular.interactive(isEnabled), in: shape)
			} else {
				content.glassEffect(.regular, in: shape)
			}
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
