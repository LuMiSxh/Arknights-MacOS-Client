// SPDX-License-Identifier: MPL-2.0

import Testing

@testable import ArknightsClient

@Suite("WallpaperSearch matching")
struct WallpaperSearchTests {
	@Test("a complete tag query matches only that exact tag, not tags that merely start with it")
	func exactTagQueryDoesNotMatchLongerTags() {
		#expect(
			WallpaperSearch.matches(
				title: "Untitled",
				tags: ["w"],
				category: .story,
				query: "w",
				selectedCategory: nil,
				knownTags: ["w"]
			))
		#expect(
			!WallpaperSearch.matches(
				title: "Untitled",
				tags: ["warfarin"],
				category: .story,
				query: "w",
				selectedCategory: nil,
				knownTags: ["w", "warfarin"]
			))
	}

	@Test("an incomplete tag query falls back to a prefix match")
	func incompleteTagQueryPrefixMatches() {
		#expect(
			WallpaperSearch.matches(
				title: "Untitled",
				tags: ["kristen wright"],
				category: .story,
				query: "kr",
				selectedCategory: nil,
				knownTags: ["kristen wright"]
			))
		#expect(
			!WallpaperSearch.matches(
				title: "Untitled",
				tags: ["amiya"],
				category: .story,
				query: "kr",
				selectedCategory: nil,
				knownTags: ["kristen wright", "amiya"]
			))
	}

	@Test("the title matches by substring regardless of tags")
	func titleMatchesBySubstring() {
		#expect(
			WallpaperSearch.matches(
				title: "2019 Christmas",
				tags: [],
				category: .holiday,
				query: "christmas",
				selectedCategory: nil,
				knownTags: []
			))
	}

	@Test("the type filter excludes non-matching categories even when the query matches")
	func typeFilterExcludesMismatchedCategory() {
		#expect(
			!WallpaperSearch.matches(
				title: "Untitled",
				tags: ["w"],
				category: .story,
				query: "w",
				selectedCategory: .holiday,
				knownTags: ["w"]
			))
		#expect(
			WallpaperSearch.matches(
				title: "Untitled",
				tags: ["w"],
				category: .story,
				query: "w",
				selectedCategory: .story,
				knownTags: ["w"]
			))
	}

	@Test("an empty query matches everything, subject only to the type filter")
	func emptyQueryMatchesEverythingWithinCategory() {
		#expect(
			WallpaperSearch.matches(
				title: "Untitled",
				tags: [],
				category: .story,
				query: "",
				selectedCategory: nil,
				knownTags: []
			))
		#expect(
			!WallpaperSearch.matches(
				title: "Untitled",
				tags: [],
				category: .story,
				query: "",
				selectedCategory: .holiday,
				knownTags: []
			))
	}

	@Test(
		"tag matching folds letters Foundation's diacritic-insensitive option doesn't decompose",
		arguments: [
			("mlynar", "młynar"),
			("ae", "ægir"),
		]
	)
	func matchingFoldsNonDecomposableLetters(query: String, tag: String) {
		#expect(
			WallpaperSearch.matches(
				title: "Untitled",
				tags: [tag],
				category: .story,
				query: query,
				selectedCategory: nil,
				knownTags: [WallpaperSearch.normalized(tag)]
			))
	}

	@Test("a multi-word query requires every term to match, in title or tags, not as one phrase")
	func multiWordQueryRequiresAllTermsToMatch() {
		#expect(
			WallpaperSearch.matches(
				title: "Twitter 460k Followers Commemorative Wallpaper",
				tags: ["angelina", "amiya"],
				category: .commemorative,
				query: "twitter angelina",
				selectedCategory: nil,
				knownTags: ["angelina", "amiya"]
			))
		#expect(
			!WallpaperSearch.matches(
				title: "Unrelated Title",
				tags: ["angelina", "amiya"],
				category: .story,
				query: "twitter angelina",
				selectedCategory: nil,
				knownTags: ["angelina", "amiya"]
			))
	}

	@Test("a multi-word query can match terms split across the title and the tags")
	func multiWordQueryMatchesTermsAcrossTitleAndTags() {
		#expect(
			WallpaperSearch.matches(
				title: "Untitled",
				tags: ["amiya", "pramanix", "angelina"],
				category: .story,
				query: "amiya angelina",
				selectedCategory: nil,
				knownTags: ["amiya", "pramanix", "angelina"]
			))
	}

	@Test("a multi-word tag typed or selected in full still matches exactly, not split into terms")
	func fullMultiWordTagStillMatchesExactly() {
		let knownTags: Set<String> = [WallpaperSearch.normalized("kristen wright"), "amiya"]
		#expect(
			WallpaperSearch.matches(
				title: "Untitled",
				tags: ["kristen wright"],
				category: .story,
				query: "kristen wright",
				selectedCategory: nil,
				knownTags: knownTags
			))
		#expect(
			!WallpaperSearch.matches(
				title: "Untitled",
				tags: ["amiya"],
				category: .story,
				query: "kristen wright",
				selectedCategory: nil,
				knownTags: knownTags
			))
	}

	@Test("an incomplete word within a multi-word query still prefix-matches")
	func incompleteWordWithinMultiWordQueryPrefixMatches() {
		#expect(
			WallpaperSearch.matches(
				title: "Untitled",
				tags: ["kristen wright", "angelina"],
				category: .story,
				query: "kr angelina",
				selectedCategory: nil,
				knownTags: ["kristen wright", "angelina"]
			))
	}

}
