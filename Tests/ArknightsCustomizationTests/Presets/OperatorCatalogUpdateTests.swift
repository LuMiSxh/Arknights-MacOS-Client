// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCustomization

@Suite("Operator catalog updates")
struct OperatorCatalogUpdateTests {
	@Test(
		"CN-only operators get a Latin fallback name",
		arguments: [
			("Kal'tsit·Esperanta", "凯尔希·思衡托", "Kal'tsit·Esperanta"),
			("GALLUS²", "GALLUS²", "GALLUS²"),
			("Вий", "维伊", "Vij"),
			(nil, "维伊", "Wei Yi"),
			("  ", "维伊", "Wei Yi"),
		] as [(String?, String, String)]
	)
	func englishFallbackName(appellation: String?, name: String, expected: String) {
		#expect(
			PresetCatalogService.englishFallbackName(appellation: appellation, name: name)
				== expected
		)
	}

	@Test("supplemental CN table adds operators missing from Global")
	func supplementalCharacterTableAddsMissingOperators() throws {
		let global = Data(
			"""
			{"char_003_kalts":{"name":"Kal'tsit","rarity":"TIER_6"},
			"char_999_hidden":{"name":"Hidden","rarity":"TIER_1","isNotObtainable":true}}
			""".utf8
		)
		let supplemental = Data(
			"""
			{"char_003_kalts":{"name":"凯尔希","appellation":"Kal'tsit","rarity":"TIER_6"},
			"char_1052_kalts2":{"name":"凯尔希·思衡托","appellation":"Kal'tsit·Esperanta","rarity":"TIER_6"}}
			""".utf8
		)

		let avatars = try PresetCatalogService.avatars(
			fromCharacterTable: global,
			supplementalTable: supplemental
		)

		#expect(avatars.map(\.id).sorted() == ["char_003_kalts", "char_1052_kalts2"])
		#expect(avatars.first { $0.id == "char_003_kalts" }?.name == "Kal'tsit")
		#expect(avatars.first { $0.id == "char_1052_kalts2" }?.name == "Kal'tsit·Esperanta")
	}

	@Test("reports added, renamed, and removed operators")
	func reportsCatalogChanges() {
		let old = [
			avatar("char_1052_kalts2", "Kal'tsit·Esperanta"),
			avatar("char_002_amiya", "Amiya"),
			avatar("char_999_gone", "Gone"),
		]
		let new = [
			avatar("char_1052_kalts2", "Kal'tsit the Esperanta"),
			avatar("char_002_amiya", "Amiya"),
			avatar("char_4231_clemnt", "Clementia"),
		]

		let changes = PresetCatalogService.avatarChanges(from: old, to: new)

		#expect(
			changes == [
				"renamed char_1052_kalts2 from Kal'tsit·Esperanta to Kal'tsit the Esperanta",
				"added char_4231_clemnt as Clementia",
				"removed char_999_gone (Gone)",
			]
		)
		#expect(PresetCatalogService.avatarChanges(from: [], to: new).isEmpty)
	}

	private func avatar(_ id: String, _ name: String) -> PresetAvatar {
		PresetAvatar(id: id, name: name, filename: "\(id).png", rarity: "TIER_6")
	}
}
