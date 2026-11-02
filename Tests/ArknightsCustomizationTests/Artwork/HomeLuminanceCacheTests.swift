// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsTestSupport
import Testing

@testable import ArknightsCustomization

@MainActor
struct HomeLuminanceCacheTests {
	@MainActor
	final class MeasureCounter {
		var count = 0
	}

	@Test func cacheHitSurvivesARelaunchWithoutMeasuringAgain() async {
		let (defaults, suiteName) = makeIsolatedDefaults("HomeLuminanceCacheTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let counter = MeasureCounter()
		let artwork = makeArtwork()
		let first = await makeCache(defaults, counter: counter)
			.score(for: artwork, cacheKey: "official.global.artwork")
		let second = await makeCache(defaults, counter: counter)
			.score(for: artwork, cacheKey: "official.global.artwork")
		#expect(first == 0.7)
		#expect(second == 0.7)
		#expect(counter.count == 1)
	}

	@Test func newAlgorithmVersionMeasuresAgain() async {
		let (defaults, suiteName) = makeIsolatedDefaults("HomeLuminanceCacheTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let counter = MeasureCounter()
		let artwork = makeArtwork()
		_ = await makeCache(defaults, counter: counter)
			.score(for: artwork, cacheKey: "custom.artwork")
		_ = await makeCache(defaults, counter: counter, version: "homeLuminance.v2")
			.score(for: artwork, cacheKey: "custom.artwork")
		#expect(counter.count == 2)
	}

	@Test func oldestScoreIsEvictedWhenTheLimitIsReached() async {
		let (defaults, suiteName) = makeIsolatedDefaults("HomeLuminanceCacheTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let counter = MeasureCounter()
		let artwork = makeArtwork()
		let cache = makeCache(defaults, counter: counter, limit: 2)
		for key in ["a", "b", "c"] {
			_ = await cache.score(for: artwork, cacheKey: key)
		}
		#expect(counter.count == 3)
		// `b` and `c` are the two newest records, so both still hit.
		_ = await cache.score(for: artwork, cacheKey: "b")
		_ = await cache.score(for: artwork, cacheKey: "c")
		#expect(counter.count == 3)
		// `a` was the oldest and must measure again.
		_ = await cache.score(for: artwork, cacheKey: "a")
		#expect(counter.count == 4)
	}

	private func makeCache(
		_ defaults: UserDefaults,
		counter: MeasureCounter,
		version: String = AppConstants.Theme.homeLuminanceVersion,
		limit: Int = AppConstants.Theme.homeLuminanceCacheLimit
	) -> HomeLuminanceCache {
		HomeLuminanceCache(
			preferences: LauncherPreferencesStore(defaults: defaults),
			measure: { _ in
				counter.count += 1
				return 0.7
			},
			version: version,
			limit: limit)
	}

	private func makeArtwork() -> NSImage {
		NSImage(size: NSSize(width: 1, height: 1))
	}
}
