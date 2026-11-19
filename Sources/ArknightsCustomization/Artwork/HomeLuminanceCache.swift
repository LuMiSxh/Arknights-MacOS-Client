// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore

// Keeps one Home luminance score per artwork across launches. A hit returns before the artwork
// is drawn, so the decode step is skipped.
@MainActor
struct HomeLuminanceCache {
	typealias Measure = @MainActor @Sendable (NSImage) async -> Double?

	let preferences: LauncherPreferencesStore
	let measure: Measure
	var version = AppConstants.Theme.homeLuminanceVersion
	var limit = AppConstants.Theme.homeLuminanceCacheLimit

	// Artwork without a cache key is measured every time and never stored.
	func score(for image: NSImage, cacheKey: String?) async -> Double? {
		guard let cacheKey else { return await measure(image) }
		let identity = "\(version).\(cacheKey)"
		if let cached = preferences.homeLuminance(for: identity) { return cached }
		guard let score = await measure(image) else { return nil }
		preferences.setHomeLuminance(score, for: identity, limit: limit)
		return score
	}
}
