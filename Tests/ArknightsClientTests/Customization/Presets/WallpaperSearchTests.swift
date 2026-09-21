// SPDX-License-Identifier: MPL-2.0

import Foundation
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

	@Test("tagsContain requires an exact tag, not a prefix or substring")
	func tagsContainRequiresExactMatch() {
		#expect(WallpaperSearch.tagsContain(["w", "amiya"], exactly: "w"))
		#expect(!WallpaperSearch.tagsContain(["warfarin"], exactly: "w"))
	}

	@Test("tagsContain folds diacritics the same way matches(...) does")
	func tagsContainFoldsDiacritics() {
		#expect(WallpaperSearch.tagsContain(["młynar"], exactly: "mlynar"))
	}

	@Test("committed tags filter exact catalog tags")
	func committedTagsFilterExactly() async throws {
		let exact = wallpaper(id: "global-586")
		let prefixOnly = wallpaper(id: "global-592")

		let matches = try await PresetGallerySearch.wallpapers(
			matching: "",
			committedTags: ["w"],
			category: nil,
			in: [exact, prefixOnly]
		)

		#expect(matches == [exact])
	}

	@Test("gallery results derive only the selected destination and preserve category counts")
	func galleryResultsKeepDestinationDataAndCounts() async throws {
		let story = wallpaper(id: "story", title: "Story")
		let holiday = wallpaper(id: "holiday", title: "Christmas")

		let results = try await PresetGallerySearch.results(
			for: .artwork,
			searchText: "",
			committedTags: [],
			selectedCategory: .story,
			avatars: [avatar(name: "Amiya")],
			wallpapers: [story, holiday]
		)

		#expect(results.filteredAvatars.isEmpty)
		#expect(results.filteredWallpapers == [story])
		#expect(results.wallpaperCategoryCounts[nil] == 2)
		#expect(results.wallpaperCategoryCounts[.story] == 1)
		#expect(results.wallpaperCategoryCounts[.holiday] == 1)
	}

	@Test("gallery result publication rejects stale and cancelled requests")
	func galleryResultsPublishOnlyForTheCurrentRequest() {
		let current = PresetGallerySearchQuery(
			destination: .artwork,
			searchText: "amiya",
			committedTags: [],
			selectedCategory: nil,
			catalogRevision: 2,
			avatarRevision: 1,
			catalogReady: true
		)
		let stale = PresetGallerySearchQuery(
			destination: current.destination,
			searchText: "ami",
			committedTags: [],
			selectedCategory: nil,
			catalogRevision: current.catalogRevision,
			avatarRevision: current.avatarRevision,
			catalogReady: true
		)
		let loading = PresetGallerySearchQuery(
			destination: current.destination,
			searchText: current.searchText,
			committedTags: current.committedTags,
			selectedCategory: current.selectedCategory,
			catalogRevision: current.catalogRevision,
			avatarRevision: current.avatarRevision,
			catalogReady: false
		)

		#expect(
			PresetGallerySearch.shouldPublishResults(
				request: current, currentQuery: current, isCancelled: false
			)
		)
		#expect(
			!PresetGallerySearch.shouldPublishResults(
				request: stale, currentQuery: current, isCancelled: false
			)
		)
		#expect(
			!PresetGallerySearch.shouldPublishResults(
				request: current, currentQuery: current, isCancelled: true
			)
		)
		#expect(
			!PresetGallerySearch.shouldPublishResults(
				request: loading, currentQuery: loading, isCancelled: false
			)
		)
	}

	private func avatar(name: String) -> PresetAvatar {
		PresetAvatar(
			id: "char_002_amiya",
			name: name,
			filename: "char_002_amiya.png",
			rarity: "TIER_5"
		)
	}

	private func wallpaper(id: String, title: String = "Untitled") -> PresetWallpaper {
		PresetWallpaper(
			id: id,
			title: title,
			fallbackOrdinal: nil,
			url: URL(string: "https://example.com/wallpaper.png")!,
			thumbnailURL: nil
		)
	}
}
