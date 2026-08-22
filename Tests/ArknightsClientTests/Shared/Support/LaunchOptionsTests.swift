// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func gameResolutionsMatchOfficialClientOptions() {
	#expect(
		GameResolution.allCases.map(\.rawValue)
			== [
				"3840x2160", "2560x1440", "2048x1080", "1920x1200", "1920x1080",
				"1680x1050", "1600x1200", "1600x1024", "1600x900", "1440x1080",
				"1360x768", "1280x960", "1280x800", "1280x768", "1280x720", "1176x664",
				"1152x864", "1024x768", "800x600", "720x480", "640x480",
			]
	)
	for resolution in GameResolution.allCases {
		#expect(resolution.rawValue == "\(resolution.width)x\(resolution.height)")
	}
}

@Test
func defaultLaunchOptionsFavorCompatibleWindow() {
	#expect(GameLaunchOptions.default.displayMode == .windowed)
	#expect(GameLaunchOptions.default.resolution == .hd)
	#expect(GameLaunchOptions.default.usesGameSettings)
	#expect(GameLaunchOptions.default.usesHighResolutionMode)
	#expect(!GameLaunchOptions.default.usesMetalPerformanceHUD)
	#expect(!GameLaunchOptions.default.usesGameMode)
	#expect(GameLaunchOptions.default.synchronizationMode == .msync)
	#expect(GameLaunchOptions.default.playerArguments.isEmpty)
}

@Test
func legacyLaunchOptionsEnableHighResolutionModeWhenDecoded() throws {
	let data = Data(
		#"{"displayMode":"windowed","resolution":"1280x720","usesGameSettings":true}"#.utf8
	)
	let options = try JSONDecoder().decode(GameLaunchOptions.self, from: data)

	#expect(options.usesHighResolutionMode)
	#expect(!options.usesMetalPerformanceHUD)
	#expect(!options.usesGameMode)
	#expect(options.synchronizationMode == .msync)
}

@Test
func launchDiagnosticsRecordEveryOptionAppliedToWine() throws {
	let sessionID = try #require(UUID(uuidString: "B59431CE-EC59-4CE0-9677-752876A01001"))
	let options = GameLaunchOptions(
		displayMode: .fullscreen,
		resolution: .quadHD,
		usesGameSettings: false,
		usesHighResolutionMode: false,
		usesMetalPerformanceHUD: true,
		usesGameMode: true,
		synchronizationMode: .esync
	)

	let diagnostic = LauncherViewModel.launchDiagnostics(
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
	#expect(diagnostic.contains("highResolution=false"))
	#expect(diagnostic.contains("metalHUD=true"))
	#expect(diagnostic.contains("gameMode=true"))
	#expect(diagnostic.contains("synchronization=ESYNC"))
	#expect(diagnostic.contains("graphicsDiagnostics=true"))
}

@Test
func prereleasePreciseScrollingSettingIsIgnoredWhenDecoded() throws {
	let data = Data(
		#"{"displayMode":"windowed","resolution":"1280x720","usesPreciseScrolling":true}"#.utf8
	)

	let options = try JSONDecoder().decode(GameLaunchOptions.self, from: data)

	#expect(options == .default)
}

@Test
func fullscreenLaunchArgumentsUseSelectedResolution() {
	let options = GameLaunchOptions(
		displayMode: .fullscreen,
		resolution: .quadHD,
		usesGameSettings: false
	)

	#expect(
		options.playerArguments
			== ["-screen-fullscreen", "1", "-screen-width", "2560", "-screen-height", "1440"]
	)
}

@Test
func windowedLaunchArgumentsDisableFullscreen() {
	let options = GameLaunchOptions(
		displayMode: .windowed,
		resolution: .fullHD,
		usesGameSettings: false
	)

	#expect(
		options.playerArguments
			== ["-screen-fullscreen", "0", "-screen-width", "1920", "-screen-height", "1080"]
	)
}

@Test
func borderlessLaunchArgumentsAddPopupWindowFlag() {
	let options = GameLaunchOptions(
		displayMode: .borderlessWindow,
		resolution: .ultraHD,
		usesGameSettings: false
	)

	#expect(
		options.playerArguments
			== [
				"-screen-fullscreen", "0", "-screen-width", "3840", "-screen-height", "2160",
				"-popupwindow",
			]
	)
}
