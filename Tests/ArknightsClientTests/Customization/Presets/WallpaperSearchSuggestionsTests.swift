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
	func ranksSuggestions() throws {
		let suggestions = try WallpaperSearch.suggestions(
			for: "w", wallpapers: wallpapers, knownTags: ["w", "warfarin"])
		#expect(suggestions.prefix(2) == ["w", "warfarin"])
		#expect(!suggestions.contains("Twitter"))
	}

	@Test("scopes later suggestions to wallpapers matching earlier terms")
	func scopesSuggestions() throws {
		let suggestions = try WallpaperSearch.suggestions(
			for: "twitter ang", wallpapers: wallpapers, knownTags: ["angelina"])
		#expect(suggestions == ["angelina"])
	}

	@Test("hides suggestions after a selection until typing resumes")
	func hidesCompletedSuggestion() throws {
		#expect(
			try WallpaperSearch.suggestions(
				for: "twitter ", wallpapers: wallpapers, knownTags: []
			).isEmpty)
		#expect(
			WallpaperSearch.trailingKnownTag(
				in: "twitter random ", canonicalTagsByNormalizedForm: [:]
			) == nil)
	}

	@Test("replaces only the active term")
	func appliesSuggestion() {
		#expect(
			WallpaperSearch.applyingSuggestion("angelina", to: "twitter ang")
				== "twitter angelina ")
	}

	@Test(
		"trailingKnownTag recognizes tags and preserves preceding query text",
		arguments: [
			("blue poison ", ["blue poison"], "blue poison", ""),
			("twitter blue poison ", ["blue poison"], "blue poison", "twitter "),
			("twitter w ", ["w"], "w", "twitter "),
			(
				"kristen wright ",
				["wright", "kristen wright"],
				"kristen wright",
				""
			),
		]
	)
	func trailingKnownTagRecognizesTags(
		query: String,
		knownTags: [String],
		expectedTag: String,
		remainingQuery: String
	) {
		let canonicalTags = Dictionary(
			uniqueKeysWithValues: knownTags.map { (WallpaperSearch.normalized($0), $0) })
		let result = WallpaperSearch.trailingKnownTag(
			in: query, canonicalTagsByNormalizedForm: canonicalTags)
		#expect(result?.tag == expectedTag)
		#expect(result?.remainingQuery == remainingQuery)
	}
}
