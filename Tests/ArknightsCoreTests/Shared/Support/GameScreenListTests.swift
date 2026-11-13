// SPDX-License-Identifier: MPL-2.0

import CoreGraphics
import Foundation
import Testing

@testable import ArknightsCore

private func screen(_ id: CGDirectDisplayID, _ uuid: String) -> GameScreenInfo {
	GameScreenInfo(
		displayID: id,
		identity: GameDisplayIdentity(uuid: uuid, name: uuid.uppercased()),
		frameSize: CGSize(width: 1512, height: 982),
		visibleSize: CGSize(width: 1512, height: 944),
		backingScaleFactor: 2,
		notchHeight: 0)
}

/// NSScreen order puts the primary display first, then B and C. CoreGraphics lists C, A, B, and
/// Wine's winemac swaps the primary entry to the front, so Wine's order is A, C, B.
private let arrangement = GameScreenList(
	screens: [screen(1, "a"), screen(2, "b"), screen(3, "c")],
	onlineDisplays: [
		GameScreenList.OnlineDisplay(id: 3, mirrorOf: 0),
		GameScreenList.OnlineDisplay(id: 1, mirrorOf: 0),
		GameScreenList.OnlineDisplay(id: 2, mirrorOf: 0),
	],
	titleBarHeight: 28)

@Test(arguments: [
	// (saved UUID, -monitor index, falls back, is primary)
	(nil as String?, 1, false, true),
	("b", 3, false, false),
	("c", 2, false, false),
	("missing", 1, true, true),
])
func gameScreenMonitorIndexFollowsWinesMonitorOrder(
	savedUUID: String?, monitorIndex: Int, fallsBack: Bool, isPrimary: Bool
) throws {
	let saved = savedUUID.map { GameDisplayIdentity(uuid: $0, name: "") }
	let resolution = try #require(arrangement.resolve(saved))

	#expect(resolution.monitorIndex == monitorIndex)
	#expect(resolution.isFallback == fallsBack)
	#expect(resolution.isPrimary == isPrimary)
}

@Test(arguments: [
	// (saved UUID, fullscreen, -monitor argument)
	(nil as String?, true, 1 as Int?),
	(nil as String?, false, nil as Int?),
	("b", true, 3 as Int?),
	("b", false, 3 as Int?),
	("missing", true, 1 as Int?),
	("missing", false, nil as Int?),
])
func monitorArgumentNamesFullscreenAndNonPrimaryDisplays(
	savedUUID: String?, fullscreen: Bool, expected: Int?
) throws {
	let saved = savedUUID.map { GameDisplayIdentity(uuid: $0, name: "") }
	let resolution = try #require(arrangement.resolve(saved))

	#expect(resolution.monitorArgument(fullscreen: fullscreen) == expected)
}

@Test
func savedDisplayIsFoundAfterReconnectUnderANewID() throws {
	// The same display returns with a new CoreGraphics ID. Its saved UUID still finds it.
	let reconnected = GameScreenList(
		screens: [screen(1, "a"), screen(9, "b")],
		onlineDisplays: [
			GameScreenList.OnlineDisplay(id: 1, mirrorOf: 0),
			GameScreenList.OnlineDisplay(id: 9, mirrorOf: 0),
		],
		titleBarHeight: 28)
	let resolution = try #require(reconnected.resolve(GameDisplayIdentity(uuid: "b", name: "")))

	#expect(resolution.screen.displayID == 9)
	#expect(!resolution.isFallback)
}

@Test
func chosenDisplayIsStoredUnderTheDisplayKey() throws {
	var options = GameLaunchOptions.default
	options.display = GameDisplayIdentity(uuid: "UUID-B", name: "Studio Display")
	let data = try JSONEncoder().encode(options)
	let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

	#expect(object["display"] as? [String: String] == ["uuid": "UUID-B", "name": "Studio Display"])
	#expect(try JSONDecoder().decode(GameLaunchOptions.self, from: data).display == options.display)
}

@Test
func storedOptionsWithoutADisplayFollowThePrimaryDisplay() throws {
	let data = Data(#"{"displayMode":"windowed"}"#.utf8)

	#expect(try JSONDecoder().decode(GameLaunchOptions.self, from: data).display == nil)
}
