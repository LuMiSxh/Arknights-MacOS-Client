// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsClient

@Suite("WallpaperSearch suggestions")
struct WallpaperSearchSuggestionsTests {
	private let wallpapers = [
		(title: "Twitter Followers", tags: ["angelina", "warfarin", "w"]),
		(title: "Rhodes Island", tags: ["amiya"]),
	]

	@Test("suggests exact tags before title words")
	func ranksSuggestions() {
		let suggestions = WallpaperSearch.suggestions(
			for: "w", wallpapers: wallpapers, knownTags: ["w", "warfarin"])
		#expect(suggestions.prefix(2) == ["w", "warfarin"])
		#expect(!suggestions.contains("Twitter"))
	}

	@Test("scopes later suggestions to wallpapers matching earlier terms")
	func scopesSuggestions() {
		let suggestions = WallpaperSearch.suggestions(
			for: "twitter ang", wallpapers: wallpapers, knownTags: ["angelina"])
		#expect(suggestions == ["angelina"])
	}

	@Test("hides suggestions after a selection until typing resumes")
	func hidesCompletedSuggestion() {
		#expect(
			WallpaperSearch.suggestions(
				for: "twitter ", wallpapers: wallpapers, knownTags: []
			).isEmpty)
	}

	@Test("replaces only the active term")
	func appliesSuggestion() {
		#expect(
			WallpaperSearch.applyingSuggestion("angelina", to: "twitter ang")
				== "twitter angelina ")
	}
}
