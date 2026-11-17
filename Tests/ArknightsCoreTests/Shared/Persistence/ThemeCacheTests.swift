// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore

@MainActor
struct ThemeCacheTests {
	@Test
	func aCacheWithAnotherSchemaVersionIsIgnored() throws {
		let temporary = try TemporaryDirectory("ThemeCacheTests")
		defer { temporary.remove() }
		let (defaults, suiteName) = makeIsolatedDefaults("ThemeCacheTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let url = temporary.url.appending(path: "Theme/theme.json")
		try FileManager.default.createDirectory(
			at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
		try Data(
			#"""
			{
			  "schemaVersion": 2,
			  "accents": [{"key": "cached", "hue": 0.5, "saturation": 0.5, "brightness": 0.5}],
			  "luminance": [{"identity": "cached", "score": 0.5}]
			}
			"""#.utf8
		).write(to: url)
		let store = LauncherPreferencesStore(defaults: defaults, themeCacheURL: url)

		#expect(store.dynamicThemeAccent(for: "cached") == nil)
		#expect(store.homeLuminance(for: "cached") == nil)
	}

	@Test
	func theCacheEvictsTheOldestEntriesPastEachLimit() throws {
		let temporary = try TemporaryDirectory("ThemeCacheTests")
		defer { temporary.remove() }
		let (defaults, suiteName) = makeIsolatedDefaults("ThemeCacheTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let url = temporary.url.appending(path: "Theme/theme.json")
		let store = LauncherPreferencesStore(defaults: defaults, themeCacheURL: url)

		let accentLimit = AppConstants.Theme.themeAccentCacheLimit
		for index in 0..<(accentLimit + 2) {
			store.setDynamicThemeAccent(
				ThemeAccentSnapshot(
					hue: Double(index) / Double(accentLimit + 2),
					saturation: 0.5,
					brightness: 0.5
				),
				for: "accent-\(index)"
			)
		}
		store.setHomeLuminance(0.1, for: "old", limit: 2)
		store.setHomeLuminance(0.2, for: "middle", limit: 2)
		store.setHomeLuminance(0.3, for: "new", limit: 2)

		let document = try #require(
			try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
		#expect((document["accents"] as? [Any])?.count == accentLimit)
		#expect((document["luminance"] as? [Any])?.count == 2)
		#expect(store.dynamicThemeAccent(for: "accent-0") == nil)
		#expect(store.dynamicThemeAccent(for: "accent-\(accentLimit + 1)") != nil)
		#expect(store.homeLuminance(for: "old") == nil)
		#expect(store.homeLuminance(for: "new") == 0.3)
	}

	@Test
	func aReadRefreshesRecencySoTheTouchedEntrySurvivesEviction() throws {
		let temporary = try TemporaryDirectory("ThemeCacheTests")
		defer { temporary.remove() }
		let (defaults, suiteName) = makeIsolatedDefaults("ThemeCacheTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(
			defaults: defaults,
			themeCacheURL: temporary.url.appending(path: "Theme/theme.json")
		)
		store.setHomeLuminance(0.1, for: "first", limit: 2)
		store.setHomeLuminance(0.2, for: "second", limit: 2)
		store.setHomeLuminance(0.3, for: "third", limit: 2)

		#expect(store.homeLuminance(for: "first") == nil)
		#expect(store.homeLuminance(for: "second") == 0.2)

		store.setHomeLuminance(0.4, for: "fourth", limit: 2)

		#expect(store.homeLuminance(for: "second") == 0.2)
		#expect(store.homeLuminance(for: "third") == nil)
	}

	@Test
	func concurrentSettersKeepEveryEntryUpToTheLimit() async throws {
		let temporary = try TemporaryDirectory("ThemeCacheTests")
		defer { temporary.remove() }
		let (defaults, suiteName) = makeIsolatedDefaults("ThemeCacheTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let store = LauncherPreferencesStore(
			defaults: defaults,
			themeCacheURL: temporary.url.appending(path: "Theme/theme.json")
		)
		let limit = AppConstants.Theme.homeLuminanceCacheLimit

		await withTaskGroup(of: Void.self) { group in
			for index in 0..<limit {
				group.addTask {
					store.setHomeLuminance(Double(index), for: "identity-\(index)", limit: limit)
				}
			}
		}

		for index in 0..<limit {
			#expect(store.homeLuminance(for: "identity-\(index)") == Double(index))
		}
	}

	@Test
	func aSecondStoreReadsWhatTheFirstPersisted() throws {
		let temporary = try TemporaryDirectory("ThemeCacheTests")
		defer { temporary.remove() }
		let (defaults, suiteName) = makeIsolatedDefaults("ThemeCacheTests")
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let url = temporary.url.appending(path: "Theme/theme.json")
		let first = LauncherPreferencesStore(defaults: defaults, themeCacheURL: url)
		first.setDynamicThemeAccent(
			ThemeAccentSnapshot(hue: 0.4, saturation: 0.5, brightness: 0.9),
			for: "accent"
		)
		first.setHomeLuminance(0.75, for: "art", limit: 4)

		let second = LauncherPreferencesStore(defaults: defaults, themeCacheURL: url)

		#expect(second.dynamicThemeAccent(for: "accent")?.hue == 0.4)
		#expect(second.homeLuminance(for: "art") == 0.75)
	}
}
