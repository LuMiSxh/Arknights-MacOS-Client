// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCore
@testable import ArknightsGameRuntime

@Test
func launchDiagnosticsRecordEveryOptionAppliedToWine() throws {
	let sessionID = try #require(UUID(uuidString: "B59431CE-EC59-4CE0-9677-752876A01001"))
	let options = GameLaunchOptions(
		displayMode: .fullscreen,
		resolution: .quadHD,
		windowSize: GameDisplaySize(width: 1600, height: 900),
		usesGameSettings: false,
		renderingMode: .metalFX,
		usesMetalPerformanceHUD: true,
		usesGameMode: true,
		synchronizationMode: .esync
	)

	let diagnostic = GameSessionController.launchDiagnostics(
		sessionID: sessionID,
		region: .korea,
		options: options,
		graphicsDiagnosticsEnabled: true
	)

	#expect(diagnostic.contains("session=B59431CE-EC59-4CE0-9677-752876A01001"))
	#expect(diagnostic.contains("region=Korea"))
	#expect(diagnostic.contains("usesGameSettings=false"))
	#expect(diagnostic.contains("displayMode=Fullscreen"))
	#expect(diagnostic.contains("resolution=2560x1440"))
	#expect(diagnostic.contains("windowSize=1600x900"))
	#expect(diagnostic.contains("rendering=metalFX"))
	#expect(diagnostic.contains("metalHUD=true"))
	#expect(diagnostic.contains("gameMode=true"))
	#expect(diagnostic.contains("synchronization=ESYNC"))
	#expect(diagnostic.contains("graphicsDiagnostics=true"))
}
