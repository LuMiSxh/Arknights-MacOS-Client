// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCustomization

@Suite("WallpaperSearch matching")
struct WallpaperSearchTests {

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
