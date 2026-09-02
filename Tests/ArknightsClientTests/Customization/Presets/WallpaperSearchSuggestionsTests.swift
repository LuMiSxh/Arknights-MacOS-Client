// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsClient

@Suite("WallpaperSearch suggestions and pill helpers")
struct WallpaperSearchSuggestionsTests {
	@Test("suggestions rank an exact match to the query first")
	func suggestionsRankExactMatchFirst() {
		let suggestions = WallpaperSearch.suggestions(
			for: "w",
			wallpapers: [
				(title: "Twitter 110k Followers", tags: []),
				(title: "Untitled", tags: ["warfarin", "w", "wang"]),
			],
			knownTags: []
		)
		#expect(suggestions.first == "w")
	}

	@Test("suggestions list tags before title words")
	func suggestionsListTagsBeforeTitleWords() throws {
		let suggestions = WallpaperSearch.suggestions(
			for: "w",
			wallpapers: [
				(title: "Windflit's Homecoming", tags: []),
				(title: "Untitled", tags: ["warfarin"]),
			],
			knownTags: []
		)
		let tagIndex = try #require(suggestions.firstIndex(of: "warfarin"))
		let titleWordIndex = try #require(suggestions.firstIndex(of: "Windflit"))
		#expect(tagIndex < titleWordIndex)
	}

	@Test("suggestions match candidates by prefix, not by substring anywhere in the word")
	func suggestionsMatchByPrefixNotSubstring() {
		let suggestions = WallpaperSearch.suggestions(
			for: "w",
			wallpapers: [
				(title: "Twitter 460k Followers", tags: []),
				(title: "Untitled", tags: ["warfarin"]),
			],
			knownTags: []
		)
		#expect(suggestions.contains("warfarin"))
		#expect(!suggestions.contains("Twitter"))
	}

	@Test("suggestions deduplicate case-insensitively")
	func suggestionsDeduplicateCaseInsensitively() {
		let suggestions = WallpaperSearch.suggestions(
			for: "w",
			wallpapers: [(title: "Untitled", tags: ["w", "W"])],
			knownTags: []
		)
		#expect(suggestions.count == 1)
	}

	@Test("an empty query has no suggestions")
	func emptyQueryHasNoSuggestions() {
		#expect(
			WallpaperSearch.suggestions(
				for: "",
				wallpapers: [(title: "Title", tags: ["tag"])],
				knownTags: []
			).isEmpty)
	}

	@Test("suggestions are capped at the requested limit")
	func suggestionsAreCapped() {
		let tags = (0..<20).map { "walrus\($0)" }
		let suggestions = WallpaperSearch.suggestions(
			for: "w",
			wallpapers: [(title: "Untitled", tags: tags)],
			knownTags: [],
			limit: 5
		)
		#expect(suggestions.count == 5)
	}

	@Test("suggestions match only the last word of a multi-word query, not the whole phrase")
	func suggestionsMatchOnlyTheLastWord() {
		let suggestions = WallpaperSearch.suggestions(
			for: "twitter ang",
			wallpapers: [
				(title: "Twitter Special", tags: ["angelina"]),
				(title: "Unrelated", tags: ["amiya"]),
			],
			knownTags: []
		)
		#expect(suggestions.contains("angelina"))
		#expect(!suggestions.contains("amiya"))
	}

	@Test("suggestions after a trailing space still match the last completed word")
	func suggestionsAfterTrailingSpaceMatchLastWord() {
		let suggestions = WallpaperSearch.suggestions(
			for: "twitter ",
			wallpapers: [(title: "Twitter 460k Followers", tags: [])],
			knownTags: []
		)
		#expect(suggestions.contains("Twitter"))
	}

	@Test(
		"""
		suggestions exclude a candidate that would combine with earlier terms to match \
		nothing, even though the candidate exists somewhere on its own
		"""
	)
	func suggestionsExcludeCandidatesThatDoNotCoOccurWithEarlierTerms() {
		let suggestions = WallpaperSearch.suggestions(
			for: "twitter ex",
			wallpapers: [
				(title: "Twitter 460k Followers Commemorative Wallpaper", tags: []),
				(title: "Untitled", tags: ["exusiai"]),
			],
			knownTags: ["exusiai"]
		)
		#expect(suggestions.isEmpty)
	}

	@Test("suggestions include a candidate that does co-occur with earlier terms")
	func suggestionsIncludeCandidatesThatCoOccurWithEarlierTerms() {
		let suggestions = WallpaperSearch.suggestions(
			for: "twitter foll",
			wallpapers: [
				(title: "Twitter 460k Followers Commemorative Wallpaper", tags: [])
			],
			knownTags: []
		)
		#expect(suggestions.contains("Followers"))
	}

	@Test("applying a suggestion replaces only the last term, keeping earlier ones")
	func applyingSuggestionReplacesLastTermOnly() {
		#expect(
			WallpaperSearch.applyingSuggestion("angelina", to: "twitter ang")
				== "twitter angelina ")
	}

	@Test("applying a suggestion to a single-term query replaces the whole thing")
	func applyingSuggestionToSingleTermQuery() {
		#expect(WallpaperSearch.applyingSuggestion("w", to: "w") == "w ")
	}

	@Test("applying a suggestion to an empty query just uses the suggestion")
	func applyingSuggestionToEmptyQuery() {
		#expect(WallpaperSearch.applyingSuggestion("w", to: "") == "w ")
	}

	@Test("applying a suggestion always appends a trailing space to continue typing")
	func applyingSuggestionAppendsTrailingSpace() {
		#expect(WallpaperSearch.applyingSuggestion("angelina", to: "ang").hasSuffix(" "))
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
