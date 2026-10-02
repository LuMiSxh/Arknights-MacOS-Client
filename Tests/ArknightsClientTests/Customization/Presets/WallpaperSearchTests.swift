// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Suite("WallpaperSearch matching")
struct WallpaperSearchTests {
	@Test(
		"matches title and category filters",
		arguments: [
			(
				"title substring",
				"2019 Christmas",
				[String](),
				WallpaperCategory.holiday.rawValue,
				"christmas",
				nil as String?,
				[String](),
				true
			),
			(
				"empty query includes every category",
				"Untitled",
				[String](),
				WallpaperCategory.story.rawValue,
				"",
				nil as String?,
				[String](),
				true
			),
			(
				"empty query still respects the selected category",
				"Untitled",
				[String](),
				WallpaperCategory.story.rawValue,
				"",
				WallpaperCategory.holiday.rawValue,
				[String](),
				false
			),
			(
				"category mismatch excludes an otherwise matching tag",
				"Untitled",
				["w"],
				WallpaperCategory.story.rawValue,
				"w",
				WallpaperCategory.holiday.rawValue,
				["w"],
				false
			),
			(
				"matching category keeps the tag result",
				"Untitled",
				["w"],
				WallpaperCategory.story.rawValue,
				"w",
				WallpaperCategory.story.rawValue,
				["w"],
				true
			),
		]
	)
	func wallpaperSearchMatchesTextAndCategoryFilters(
		caseLabel: String,
		title: String,
		tags: [String],
		categoryRawValue: String,
		query: String,
		selectedCategoryRawValue: String?,
		knownTags: [String],
		expected: Bool
	) throws {
		let category = try #require(WallpaperCategory(rawValue: categoryRawValue))
		let selectedCategory = selectedCategoryRawValue.flatMap(WallpaperCategory.init(rawValue:))
		let matches = WallpaperSearch.matches(
			title: title,
			tags: tags,
			category: category,
			query: query,
			selectedCategory: selectedCategory,
			knownTags: Set(knownTags.map { WallpaperSearch.normalized($0) })
		)
		#expect(matches == expected, Comment(rawValue: caseLabel))
	}

	@Test(
		"matches complete tags exactly and incomplete tags by prefix",
		arguments: [
			("complete tag", ["w"], "w", ["w"], true),
			("complete tag is not a prefix", ["warfarin"], "w", ["w", "warfarin"], false),
			("incomplete tag prefix", ["kristen wright"], "kr", ["kristen wright"], true),
			(
				"unrelated tag has no prefix match", ["amiya"], "kr", ["kristen wright", "amiya"],
				false
			),
			("non-decomposable diacritic", ["młynar"], "mlynar", ["młynar"], true),
			("ligature", ["ægir"], "ae", ["ægir"], true),
			(
				"complete multi-word tag", ["kristen wright"], "kristen wright",
				["kristen wright", "amiya"], true
			),
			(
				"multi-word query is not split over another tag", ["amiya"], "kristen wright",
				["kristen wright", "amiya"], false
			),
		]
	)
	func wallpaperSearchMatchesExpectedTags(
		caseLabel: String,
		tags: [String],
		query: String,
		knownTags: [String],
		expected: Bool
	) {
		let matches = WallpaperSearch.matches(
			title: "Untitled",
			tags: tags,
			category: .story,
			query: query,
			selectedCategory: nil,
			knownTags: Set(knownTags.map { WallpaperSearch.normalized($0) })
		)
		#expect(matches == expected, Comment(rawValue: caseLabel))
	}

	@Test(
		"requires every search term to match across the title or tags",
		arguments: [
			(
				"all terms match across title and tags",
				"Twitter 460k Followers Commemorative Wallpaper",
				["angelina", "amiya"],
				"twitter angelina",
				["angelina", "amiya"],
				true
			),
			(
				"one missing term rejects the result",
				"Unrelated Title",
				["angelina", "amiya"],
				"twitter angelina",
				["angelina", "amiya"],
				false
			),
			(
				"terms can match separate tags",
				"Untitled",
				["amiya", "pramanix", "angelina"],
				"amiya angelina",
				["amiya", "pramanix", "angelina"],
				true
			),
			(
				"an incomplete term keeps prefix matching",
				"Untitled",
				["kristen wright", "angelina"],
				"kr angelina",
				["kristen wright", "angelina"],
				true
			),
		]
	)
	func wallpaperSearchRequiresAllTerms(
		caseLabel: String,
		title: String,
		tags: [String],
		query: String,
		knownTags: [String],
		expected: Bool
	) {
		let matches = WallpaperSearch.matches(
			title: title,
			tags: tags,
			category: .story,
			query: query,
			selectedCategory: nil,
			knownTags: Set(knownTags.map { WallpaperSearch.normalized($0) })
		)
		#expect(matches == expected, Comment(rawValue: caseLabel))
	}

	@Test(arguments: [
		("exact tag", ["w", "amiya"], "w", true),
		("prefix is not exact", ["warfarin"], "w", false),
		("diacritic folds", ["młynar"], "mlynar", true),
	])
	func tagsContainUsesExactNormalizedMatching(
		caseLabel: String,
		tags: [String],
		query: String,
		expected: Bool
	) {
		#expect(
			WallpaperSearch.tagsContain(tags, exactly: query) == expected,
			Comment(rawValue: caseLabel))
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
