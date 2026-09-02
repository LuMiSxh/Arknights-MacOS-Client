// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Suite("PresetCatalogModels")
struct PresetCatalogModelsTests {
	@Test("decodes plain string image fields")
	func decodesPlainStringImages() throws {
		let json = #"""
			{
			  "id": 4431,
			  "title": "Crossing",
			  "image1": "https://webusstatic.yo-star.com/a.png",
			  "smallImage": "https://webusstatic.yo-star.com/a-small.jpg"
			}
			"""#
		let row = try JSONDecoder().decode(YostarGalleryRow.self, from: Data(json.utf8))

		#expect(row.id == 4431)
		#expect(row.title == "Crossing")
		#expect(row.image1 == "https://webusstatic.yo-star.com/a.png")
		#expect(row.smallImage == "https://webusstatic.yo-star.com/a-small.jpg")
	}

	@Test("decodes single-element array-wrapped image fields")
	func decodesArrayWrappedImages() throws {
		let json = #"""
			{
			  "id": 172197591815510122,
			  "title": "70万人突破記念イラスト",
			  "image1": ["https://webusstatic.yo-star.com/ark_jp_web/assets/172197591815510122/01.jpg"],
			  "smallImage": ["https://webusstatic.yo-star.com/ark_jp_web/assets/172197591815510122/small.jpg"]
			}
			"""#
		let row = try JSONDecoder().decode(YostarGalleryRow.self, from: Data(json.utf8))

		#expect(
			row.image1
				== "https://webusstatic.yo-star.com/ark_jp_web/assets/172197591815510122/01.jpg"
		)
		#expect(
			row.smallImage
				== "https://webusstatic.yo-star.com/ark_jp_web/assets/172197591815510122/small.jpg"
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
		]
	)
	func classifiesTitles(title: String, expected: WallpaperCategory) {
		#expect(WallpaperCategory(title: title) == expected)
	}

	@Test("anniversary livestream wallpapers count as celebration, not commemorative")
	func livestreamAnniversaryIsCelebration() {
		#expect(
			WallpaperCategory(title: "5.5th Livestream Commemorative Wallpaper")
				== .celebration)
	}
}
