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
}
