// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCustomization

@Suite("PresetCatalogModels")
struct PresetCatalogModelsTests {
	enum UpstreamPayload: CaseIterable {
		case plainStringFields
		case arrayWrappedFields
		case missingSmallImage
		case galleryRowIdentity
		case characterTable
		case legacyWallpaperCache
	}

	@Test(
		"decodes gallery image fields, character tables and legacy wallpaper caches",
		arguments: UpstreamPayload.allCases
	)
	func decodesGalleryImageFields(payload: UpstreamPayload) throws {
		func galleryRow(_ json: String) throws -> YostarGalleryRow {
			try JSONDecoder().decode(YostarGalleryRow.self, from: Data(json.utf8))
		}
		switch payload {
		case .plainStringFields:
			let row = try galleryRow(
				#"{"id":4431,"title":"Crossing","image1":"https://webusstatic.yo-star.com/a.png","smallImage":"https://webusstatic.yo-star.com/a-small.jpg"}"#
			)
			#expect(row.id == 4431)
			#expect(row.title == "Crossing")
			#expect(row.image1 == "https://webusstatic.yo-star.com/a.png")
			#expect(row.smallImage == "https://webusstatic.yo-star.com/a-small.jpg")
		case .arrayWrappedFields:
			let row = try galleryRow(
				#"{"id":172197591815510122,"title":"70万人突破記念イラスト","image1":["https://webusstatic.yo-star.com/01.jpg"],"smallImage":["https://webusstatic.yo-star.com/small.jpg"]}"#
			)
			#expect(row.id == 172_197_591_815_510_122)
			#expect(row.image1 == "https://webusstatic.yo-star.com/01.jpg")
			#expect(row.smallImage == "https://webusstatic.yo-star.com/small.jpg")
		case .missingSmallImage:
			let row = try galleryRow(
				#"{"id":1,"title":"Fallback","image1":"https://webusstatic.yo-star.com/only.png"}"#
			)
			#expect(row.smallImage == "https://webusstatic.yo-star.com/only.png")
		case .galleryRowIdentity:
			let row = try galleryRow(
				#"{"id":42,"title":"  Crossing the Rhine  ","author":" Yostar Art ","description":" A river crossing illustration ","image1":"https://webusstatic.yo-star.com/crossing.png"}"#
			)
			let wallpaper = try #require(
				PresetCatalogService.wallpaper(from: row, page: 1, ordinal: 1))
			#expect(wallpaper.id == "wp_42")
			#expect(wallpaper.title == "Crossing the Rhine")
			#expect(wallpaper.author == "Yostar Art")
			#expect(wallpaper.description == "A river crossing illustration")

			let fallbackRow = try galleryRow(
				#"{"title":"Untitled","image1":"https://webusstatic.yo-star.com/untitled.png"}"#)
			let fallback = try #require(
				PresetCatalogService.wallpaper(from: fallbackRow, page: 2, ordinal: 3))
			#expect(fallback.id == "wp_2_2")
		case .characterTable:
			let entry = try JSONDecoder().decode(
				RawCharacterEntry.self,
				from: Data(
					#"{"name":"Amiya","rarity":5,"profession":"CASTER","subProfessionId":"corecaster","nationId":"Rhodes","groupId":"Rhodes Island","teamId":"Rhodes Island","tagList":["Support"]}"#
						.utf8))
			#expect(entry.subProfessionID == "corecaster")
			#expect(entry.groupID == "Rhodes Island")
			#expect(entry.tagList == ["Support"])
		case .legacyWallpaperCache:
			let wallpaper = try JSONDecoder().decode(
				PresetWallpaper.self,
				from: Data(
					#"{"id":"crossing","title":"Crossing","fallbackOrdinal":null,"url":"https://webusstatic.yo-star.com/crossing.png","thumbnailURL":null}"#
						.utf8))
			#expect(wallpaper.title == "Crossing")
			#expect(wallpaper.author == nil)
			#expect(wallpaper.description == nil)
		}
	}
}
