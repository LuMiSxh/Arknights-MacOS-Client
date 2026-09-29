// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Suite("PresetCatalogModels")
struct PresetCatalogModelsTests {
	@Test(
		"decodes gallery image fields from strings or one-element arrays",
		arguments: [
			(
				"plain string fields",
				#"""
				{
				  "id": 4431,
				  "title": "Crossing",
				  "image1": "https://webusstatic.yo-star.com/a.png",
				  "smallImage": "https://webusstatic.yo-star.com/a-small.jpg"
				}
				"""#,
				4431,
				"Crossing",
				"https://webusstatic.yo-star.com/a.png",
				"https://webusstatic.yo-star.com/a-small.jpg"
			),
			(
				"single-element array-wrapped fields",
				#"""
				{
				  "id": 172197591815510122,
				  "title": "70万人突破記念イラスト",
				  "image1": ["https://webusstatic.yo-star.com/ark_jp_web/assets/172197591815510122/01.jpg"],
				  "smallImage": ["https://webusstatic.yo-star.com/ark_jp_web/assets/172197591815510122/small.jpg"]
				}
				"""#,
				172_197_591_815_510_122,
				"70万人突破記念イラスト",
				"https://webusstatic.yo-star.com/ark_jp_web/assets/172197591815510122/01.jpg",
				"https://webusstatic.yo-star.com/ark_jp_web/assets/172197591815510122/small.jpg"
			),
		]
	)
	func decodesGalleryImageFields(
		caseLabel: String,
		json: String,
		expectedID: Int,
		expectedTitle: String,
		expectedImage: String,
		expectedSmallImage: String
	) throws {
		let row = try JSONDecoder().decode(YostarGalleryRow.self, from: Data(json.utf8))

		#expect(row.id == expectedID, Comment(rawValue: caseLabel))
		#expect(row.title == expectedTitle, Comment(rawValue: caseLabel))
		#expect(
			row.image1 == expectedImage,
			Comment(rawValue: caseLabel)
		)
		#expect(
			row.smallImage == expectedSmallImage,
			Comment(rawValue: caseLabel)
		)
	}

	@Test("falls back from missing smallImage to image1")
	func fallsBackToImage1WhenSmallImageMissing() throws {
		let json = #"""
			{
			  "id": 1,
			  "title": "Fallback",
			  "image1": "https://webusstatic.yo-star.com/only.png"
			}
			"""#
		let row = try JSONDecoder().decode(YostarGalleryRow.self, from: Data(json.utf8))

		#expect(row.smallImage == "https://webusstatic.yo-star.com/only.png")
	}

	@Test("wallpaper tag catalog returns empty tags for unknown IDs")
	func tagCatalogReturnsEmptyForUnknownID() {
		#expect(WallpaperTagCatalog.tags(for: "global-not-a-real-id").isEmpty)
	}

	@Test("wallpaper tag manifest decodes a schemaVersion and tag dictionary")
	func manifestDecodesSchema() throws {
		let json = #"""
			{
			  "schemaVersion": 1,
			  "tags": {
			    "global-4431": ["amiya", "closer", "rhodes-island"]
			  }
			}
			"""#
		let manifest = try JSONDecoder().decode(
			WallpaperTagManifest.self, from: Data(json.utf8))

		#expect(manifest.schemaVersion == 1)
		#expect(manifest.tags["global-4431"] == ["amiya", "closer", "rhodes-island"])
	}

	@Test(
		"classifies wallpaper titles into categories",
		arguments: [
			("Episode 6: Partial Necrosis Opening", WallpaperCategory.story),
			("Twitter 110k Followers Commemorative Wallpaper", WallpaperCategory.commemorative),
			("2019 Christmas", WallpaperCategory.holiday),
			("4th Anniversary Celebration", WallpaperCategory.celebration),
			("3rd Anniverary Celebration", WallpaperCategory.celebration),
			(
				"5.5th Livestream Commemorative Wallpaper",
				WallpaperCategory.celebration
			),
		]
	)
	func classifiesTitles(title: String, expected: WallpaperCategory) {
		#expect(WallpaperCategory(title: title) == expected)
	}
}
