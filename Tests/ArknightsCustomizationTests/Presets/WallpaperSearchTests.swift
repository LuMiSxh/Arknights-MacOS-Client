// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCustomization

@Suite("WallpaperSearch matching")
struct WallpaperSearchTests {

	@Test(
		"matches title, category, tag and multi-term filters",
		arguments: [
			("title substring", "2019 Christmas", [], "christmas", nil, [], true),
			("empty query respects the category", "Untitled", [], "", .holiday, [], false),
			(
				"category mismatch excludes a tag match", "Untitled", ["w"], "w", .holiday, ["w"],
				false
			),
			("matching category keeps a tag match", "Untitled", ["w"], "w", .story, ["w"], true),
			(
				"complete tag is exact", "Untitled", ["warfarin"], "w", nil, ["w", "warfarin"],
				false
			),
			(
				"incomplete tag matches by prefix", "Untitled", ["kristen wright"], "kr", nil,
				["kristen wright"], true
			),
			("diacritics fold", "Untitled", ["młynar"], "mlynar", nil, ["młynar"], true),
			("ligatures fold", "Untitled", ["ægir"], "ae", nil, ["ægir"], true),
			(
				"multi-word query is not split over another tag", "Untitled", ["amiya"],
				"kristen wright", nil, ["kristen wright", "amiya"], false
			),
			(
				"terms match across title and tags", "Twitter 460k Followers", ["angelina"],
				"twitter angelina", nil, ["angelina"], true
			),
			(
				"one missing term rejects the result", "Unrelated Title", ["angelina"],
				"twitter angelina", nil, ["angelina"], false
			),
			(
				"terms match separate tags", "Untitled", ["amiya", "angelina"], "amiya angelina",
				nil, ["amiya", "angelina"], true
			),
		] as [(String, String, [String], String, WallpaperCategory?, [String], Bool)]
	)
	func wallpaperSearchMatchesTextAndCategoryFilters(
		label: String,
		title: String,
		tags: [String],
		query: String,
		selected: WallpaperCategory?,
		knownTags: [String],
		expected: Bool
	) {
		let matches = PresetSearch.matches(
			title: title,
			tags: tags,
			category: .story,
			query: query,
			selectedCategory: selected,
			knownTags: Set(knownTags.map { PresetSearch.normalized($0) })
		)
		#expect(matches == expected, Comment(rawValue: label))
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
			PresetSearch.shouldPublishResults(
				request: current, currentQuery: current, isCancelled: false
			)
		)
		#expect(
			!PresetSearch.shouldPublishResults(
				request: stale, currentQuery: current, isCancelled: false
			)
		)
		#expect(
			!PresetSearch.shouldPublishResults(
				request: current, currentQuery: current, isCancelled: true
			)
		)
		#expect(
			!PresetSearch.shouldPublishResults(
				request: loading, currentQuery: loading, isCancelled: false
			)
		)
	}
}
