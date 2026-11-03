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

/// Visual role of a launcher surface. Each role owns its default shape, fill, and edge.
package enum LauncherSurfaceKind: Equatable {
	/// Dialogs layered over the sheet.
	case modal
	/// Rows grouped under a section label. No glass.
	case group
	/// Floating action pill at the foot of a surface.
	case footer
}

extension View {
	/// The only place that chooses between glass, tinted glass, and the macOS 15 material
	/// fallback for launcher surfaces. Reduce Transparency skips the glass and keeps the tint.
	package func launcherSurface(_ kind: LauncherSurfaceKind) -> some View {
		modifier(LauncherSurfaceModifier(kind: kind, customShape: nil))
	}

	/// Same as `launcherSurface(_:)`, with a caller-supplied shape for surfaces whose shape
	/// changes at runtime, such as an expandable footer.
	package func launcherSurface<S: Shape>(_ kind: LauncherSurfaceKind, in shape: S) -> some View {
		modifier(LauncherSurfaceModifier(kind: kind, customShape: AnyShape(shape)))
	}
}

private struct LauncherSurfaceModifier: ViewModifier {
	let kind: LauncherSurfaceKind
	let customShape: AnyShape?
	@Environment(\.launcherTheme) private var theme
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency

	private var isDark: Bool { colorScheme == .dark }

	private var defaultShape: AnyShape {
		switch kind {
		case .modal: AnyShape(RoundedRectangle(cornerRadius: 20))
		case .group: AnyShape(RoundedRectangle(cornerRadius: 12))
		case .footer: AnyShape(Capsule())
		}
	}

	@ViewBuilder
	func body(content: Content) -> some View {
		let shape = customShape ?? defaultShape
		switch kind {
		case .modal:
			surface(content, tint: theme.modalTint, shape: shape)
				.clipShape(shape)
				.background {
					shape.fill(theme.modalTint)
						.shadow(
							color: .black.opacity(isDark ? 0.45 : 0.14),
							radius: isDark ? 32 : 24, y: isDark ? 12 : 8)
				}
				.overlay { shape.stroke(theme.dialogHairline) }
		case .group:
			content
				.background {
					shape.fill(theme.groupFill)
						.shadow(color: isDark ? .clear : .black.opacity(0.04), radius: 2, y: 1)
				}
				.overlay { shape.stroke(theme.hairline) }
		case .footer:
			if isDark {
				surface(content, tint: theme.footerGlassTint, shape: shape)
					.shadow(color: .black.opacity(0.35), radius: 10, y: 4)
			} else {
				// Light footers skip Liquid Glass: macOS 27 glass adds a black backplate under
				// the tint, which greys the pill.
				content
					.background {
						if !reduceTransparency { shape.fill(.regularMaterial) }
					}
					.background { shape.fill(theme.footerGlassTint) }
					.overlay { shape.stroke(theme.hairline) }
					.shadow(color: .black.opacity(0.12), radius: 12, y: 4)
			}
		}
	}

	/// Fills the tint under the glass. Glass sits above the tint, since a tint under the glass
	/// lightens to grey. Reduce Transparency keeps the tint and skips the glass.
	@ViewBuilder
	private func surface(_ content: Content, tint: Color, shape: AnyShape) -> some View {
		let filled = content.background { shape.fill(tint) }
		if reduceTransparency {
			filled
		} else {
			filled.adaptiveGlassEffect(in: shape)
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

	fileprivate static var isMacOS27Available: Bool {
		if #available(macOS 27, *) { return true }
		return false
	}

	fileprivate static var isMacOS26Available: Bool {
		if #available(macOS 26, *) { return true }
		return false
	}
}

private struct AdaptiveGlassEffectModifier<ShapeType: Shape>: ViewModifier {
	@Environment(\.launcherTheme) private var theme
	let tint: Color?
	let borderTint: Color?
	let shape: ShapeType
	let showsBorder: Bool
	let isInteractive: Bool
	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
	@Environment(\.accessibilityShowBorders) private var showBorders
	@Environment(\.isEnabled) private var isEnabled
	@Environment(\.colorScheme) private var colorScheme

	@ViewBuilder
	func body(content: Content) -> some View {
		switch AdaptiveGlassSurfaceTreatment.resolve(
			isMacOS27Available: AdaptiveGlassSurfaceTreatment.isMacOS27Available,
			isMacOS26Available: AdaptiveGlassSurfaceTreatment.isMacOS26Available,
			reduceTransparency: reduceTransparency,
			showBorders: showBorders || showsBorder,
			hasTint: tint != nil
		) {
		case .reducedTransparency(let showBorders):
			content
				.background {
					shape.fill(theme.sheetSolid)
						.overlay { shape.fill(tint ?? Color.clear) }
				}
				.overlay {
					shape
						.stroke(
							(effectiveBorderTint ?? theme.controlStroke).opacity(
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

	@available(macOS 26, *)
	private var glass: Glass {
		(tint.map { Glass.regular.tint($0) } ?? .regular)
			.interactive(isInteractive && isEnabled)
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
		let backplateTint = hasTint ? macOS27ColorTint : nil
		macOS27Backplate(content, tint: backplateTint)
			.glassEffect(
				(backplateTint.map { Glass.regular.tint($0) } ?? .regular)
					.interactive(isInteractive && isEnabled),
				in: shape
			)
	}

	@ViewBuilder
	private func macOS27Backplate(_ content: Content, tint: Color?) -> some View {
		if let tint {
			content
				.background(tint, in: shape)
				.background(
					backplate.opacity(
						AdaptiveGlassSurfaceTreatment.macOS27ChromaticBackplateOpacity
					),
					in: shape
				)
		} else {
			content.background(
				backplate.opacity(AdaptiveGlassSurfaceTreatment.macOS27BackplateOpacity),
				in: shape
			)
		}
	}

	// macOS 27 glass needs a backplate to hold its tint. A black one turns glass on a light sheet muddy.
	private var backplate: Color {
		colorScheme == .dark ? .black : .white
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
		guard chroma > 0.08 else { return theme.textSecondary }
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
		content.glassEffect(glass, in: shape)
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

/// Groups sibling glass surfaces so macOS 26 can blend and morph them as they appear,
/// disappear, or resize next to each other. Earlier systems render the content unchanged.
package struct AdaptiveGlassGroup<Content: View>: View {
	let spacing: CGFloat
	@ViewBuilder package let content: Content

	package init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
		self.spacing = spacing
		self.content = content()
	}

	package var body: some View {
		if #available(macOS 26, *) {
			GlassEffectContainer(spacing: spacing) {
				content
			}
		} else {
			content
		}
	}
}
