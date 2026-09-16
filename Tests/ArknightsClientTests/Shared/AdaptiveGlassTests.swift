// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsClient

@Test
func adaptiveGlassKeepsMacOS27ContrastCorrectionSeparateFromOtherSurfaces() {
	#expect(
		AdaptiveGlassSurfaceTreatment.resolve(
			isMacOS27Available: true,
			isMacOS26Available: true,
			reduceTransparency: false,
			showBorders: false,
			hasTint: true
		) == .macOS27(showBorders: false, hasTint: true)
	)
	#expect(
		AdaptiveGlassSurfaceTreatment.resolve(
			isMacOS27Available: true,
			isMacOS26Available: true,
			reduceTransparency: false,
			showBorders: true,
			hasTint: false
		) == .macOS27(showBorders: true, hasTint: false)
	)
	#expect(
		AdaptiveGlassSurfaceTreatment.resolve(
			isMacOS27Available: false,
			isMacOS26Available: true,
			reduceTransparency: false,
			showBorders: true,
			hasTint: true
		) == .macOS26
	)
	#expect(
		AdaptiveGlassSurfaceTreatment.resolve(
			isMacOS27Available: false,
			isMacOS26Available: false,
			reduceTransparency: false,
			showBorders: true,
			hasTint: true
		) == .material
	)
	#expect(
		AdaptiveGlassSurfaceTreatment.resolve(
			isMacOS27Available: true,
			isMacOS26Available: true,
			reduceTransparency: true,
			showBorders: true,
			hasTint: true
		) == .reducedTransparency(showBorders: true)
	)
	#expect(AdaptiveGlassSurfaceTreatment.macOS27TintOpacity(for: 0.08) == 0.24)
	#expect(AdaptiveGlassSurfaceTreatment.macOS27TintOpacity(for: 0.52) == 0.52)
	#expect(AdaptiveGlassSurfaceTreatment.macOS27BackplateOpacity == 0.68)
	#expect(AdaptiveGlassSurfaceTreatment.macOS27ChromaticBackplateOpacity == 0.44)
}
