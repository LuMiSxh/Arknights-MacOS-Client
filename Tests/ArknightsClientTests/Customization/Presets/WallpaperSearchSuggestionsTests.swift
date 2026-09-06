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

	@Test("trailingKnownTag recognizes a multi-word tag as one unit, not its last word alone")
	func trailingKnownTagRecognizesMultiWordTags() {
		let canonicalTags = [WallpaperSearch.normalized("blue poison"): "blue poison"]
		let result = WallpaperSearch.trailingKnownTag(
			in: "blue poison ", canonicalTagsByNormalizedForm: canonicalTags)
		#expect(result?.tag == "blue poison")
		#expect(result?.remainingQuery == "")
	}

	@Test("trailingKnownTag keeps earlier free text when the trailing phrase is the tag")
	func trailingKnownTagKeepsEarlierFreeText() {
		let canonicalTags = [WallpaperSearch.normalized("blue poison"): "blue poison"]
		let result = WallpaperSearch.trailingKnownTag(
			in: "twitter blue poison ", canonicalTagsByNormalizedForm: canonicalTags)
		#expect(result?.tag == "blue poison")
		#expect(result?.remainingQuery == "twitter ")
	}

	@Test("trailingKnownTag still recognizes a single-word tag")
	func trailingKnownTagRecognizesSingleWordTags() {
		let canonicalTags = [WallpaperSearch.normalized("w"): "w"]
		let result = WallpaperSearch.trailingKnownTag(
			in: "twitter w ", canonicalTagsByNormalizedForm: canonicalTags)
		#expect(result?.tag == "w")
		#expect(result?.remainingQuery == "twitter ")
	}

	@Test("trailingKnownTag prefers the longest match over a shorter trailing word alone")
	func trailingKnownTagPrefersLongestMatch() {
		let canonicalTags = [WallpaperSearch.normalized("kristen wright"): "kristen wright"]
		let result = WallpaperSearch.trailingKnownTag(
			in: "kristen wright ", canonicalTagsByNormalizedForm: canonicalTags)
		#expect(result?.tag == "kristen wright")
		#expect(result?.remainingQuery == "")
	}

	@Test("trailingKnownTag returns nil when nothing trailing is a known tag")
	func trailingKnownTagReturnsNilWhenNoMatch() {
		#expect(
			WallpaperSearch.trailingKnownTag(
				in: "twitter random ", canonicalTagsByNormalizedForm: [:]
			) == nil)
	}
}
