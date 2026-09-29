// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Suite
struct PresetCatalogSearchTests {
	@Test
	func operatorMetadataIsSearchable() async throws {
		let avatar = PresetAvatar(
			id: "char_001_test",
			name: "Test Operator",
			filename: "char_001_test.png",
			rarity: "TIER_6",
			appellation: "The Example",
			profession: "CASTER",
			subProfessionID: "corecaster",
			nationID: "Victoria",
			groupID: "Rhodes Island",
			teamID: "Rhodes Island",
			tagList: ["Support"]
		)

		let matches = try await PresetCatalogSearch.avatars(matching: "support", in: [avatar])

		#expect(matches == [avatar])
	}

	@Test
	func characterTableMetadataDecodesNumericRarityAndStableFields() throws {
		let data = Data(
			"""
			{"name":"Amiya","rarity":5,"profession":"CASTER","subProfessionId":"corecaster","nationId":"Rhodes","groupId":"Rhodes Island","teamId":"Rhodes Island","tagList":["Support"]}
			""".utf8
		)

		let entry = try JSONDecoder().decode(RawCharacterEntry.self, from: data)

		#expect(entry.rarity == "TIER_6")
		#expect(entry.profession == "CASTER")
		#expect(entry.subProfessionID == "corecaster")
		#expect(entry.groupID == "Rhodes Island")
		#expect(entry.tagList == ["Support"])
	}

	@Test
	func oneCharacterTypoRanksTheClosestPresetAcrossCatalogs() async throws {
		let closestAvatar = PresetAvatar(
			id: "char_002_amiya",
			name: "Amiya",
			filename: "char_002_amiya.png",
			rarity: "TIER_5"
		)
		let unrelatedAvatar = PresetAvatar(
			id: "char_003_kalts",
			name: "Kal'tsit",
			filename: "char_003_kalts.png",
			rarity: "TIER_6"
		)

		let avatarMatches = try await PresetCatalogSearch.avatars(
			matching: "Amiyaa", in: [unrelatedAvatar, closestAvatar])
		#expect(avatarMatches.first == closestAvatar, "operator query")

		let closestWallpaper = PresetWallpaper(
			id: "crossing",
			title: "Crossing the Rhine",
			fallbackOrdinal: nil,
			url: URL(string: "https://arknights.global/crossing.png")!,
			thumbnailURL: nil
		)
		let unrelatedWallpaper = PresetWallpaper(
			id: "summer",
			title: "Summer Celebration",
			fallbackOrdinal: nil,
			url: URL(string: "https://arknights.global/summer.png")!,
			thumbnailURL: nil
		)
		let wallpaperMatches = try await PresetCatalogSearch.wallpapers(
			matching: "Rhina", in: [unrelatedWallpaper, closestWallpaper])
		#expect(wallpaperMatches.first == closestWallpaper, "wallpaper query")
	}

	@Test(
		"wallpaper search matches display titles after trimming surrounding whitespace",
		arguments: ["rhine", "  rhine  "]
	)
	func wallpaperSearchMatchesDisplayTitle(query: String) async throws {
		let wallpaper = PresetWallpaper(
			id: "crossing",
			title: "Crossing the Rhine",
			fallbackOrdinal: nil,
			url: URL(string: "https://arknights.global/crossing.png")!,
			thumbnailURL: nil
		)

		let matches = try await PresetCatalogSearch.wallpapers(matching: query, in: [wallpaper])

		#expect(matches == [wallpaper])
	}

	@Test
	func shortUnrelatedQueryDoesNotUseFuzzyMatching() async throws {
		let wallpaper = PresetWallpaper(
			id: "crossing",
			title: "Crossing the Rhine",
			fallbackOrdinal: nil,
			url: URL(string: "https://arknights.global/crossing.png")!,
			thumbnailURL: nil
		)

		let matches = try await PresetCatalogSearch.wallpapers(matching: "z", in: [wallpaper])

		#expect(matches.isEmpty)
	}

	@Test
	func wallpaperRowsKeepAPIIdentityAndOptionalMetadata() throws {
		let data = Data(
			"""
			{"id":42,"title":"  Crossing the Rhine  ","author":" Yostar Art ","description":" A river crossing illustration ","image1":"https://webusstatic.yo-star.com/crossing.png","smallImage":["https://webusstatic.yo-star.com/crossing-small.png"]}
			""".utf8
		)
		let row = try JSONDecoder().decode(YostarGalleryRow.self, from: data)
		let wallpaper = try #require(
			PresetCatalogService.wallpaper(from: row, page: 1, ordinal: 1)
		)

		#expect(wallpaper.id == "wp_42")
		#expect(wallpaper.title == "Crossing the Rhine")
		#expect(wallpaper.author == "Yostar Art")
		#expect(wallpaper.description == "A river crossing illustration")

		let fallbackRow = try JSONDecoder().decode(
			YostarGalleryRow.self,
			from: Data(
				"""
				{"title":"Untitled","image1":"https://webusstatic.yo-star.com/untitled.png"}
				""".utf8
			)
		)
		let fallback = try #require(
			PresetCatalogService.wallpaper(from: fallbackRow, page: 2, ordinal: 3)
		)
		#expect(fallback.id == "wp_2_2")
	}

	@Test
	func wallpaperMetadataParticipatesInSearch() async throws {
		let wallpaper = PresetWallpaper(
			id: "wp_42",
			title: "Crossing the Rhine",
			fallbackOrdinal: nil,
			url: URL(string: "https://webusstatic.yo-star.com/crossing.png")!,
			thumbnailURL: nil,
			author: "Yostar Art",
			description: "A river crossing illustration"
		)

		for query in ["yostar", "illustration"] {
			#expect(
				try await PresetCatalogSearch.wallpapers(matching: query, in: [wallpaper])
					== [wallpaper])
		}
	}

	@Test
	func legacyWallpaperCacheDecodesWithoutNewMetadataFields() throws {
		let data = Data(
			"""
			{"id":"crossing","title":"Crossing","fallbackOrdinal":null,"url":"https://webusstatic.yo-star.com/crossing.png","thumbnailURL":null}
			""".utf8
		)

		let wallpaper = try JSONDecoder().decode(PresetWallpaper.self, from: data)

		#expect(wallpaper.title == "Crossing")
		#expect(wallpaper.author == nil)
		#expect(wallpaper.description == nil)
	}
}
