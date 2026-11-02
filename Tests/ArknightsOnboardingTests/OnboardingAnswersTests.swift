// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import CoreGraphics
import Foundation
import Testing

@testable import ArknightsCore
@testable import ArknightsOnboarding

private let laptop = GameScreenMetrics(
	visibleSize: CGSize(width: 1470, height: 919), pixelSize: CGSize(width: 2940, height: 1912))
private let scaled4K = GameScreenMetrics(
	visibleSize: CGSize(width: 3008, height: 1659), pixelSize: CGSize(width: 6016, height: 3384))

@MainActor
private func makePreferences() -> (
	LauncherPreferencesController, LauncherPreferencesStore, () -> Void
) {
	let (defaults, suiteName) = makeIsolatedDefaults("OnboardingAnswersTests")
	let store = LauncherPreferencesStore(defaults: defaults)
	return (
		LauncherPreferencesController(store: store), store,
		{ defaults.removePersistentDomain(forName: suiteName) }
	)
}

@MainActor
@Test
func appliedWindowAnswersAreReadBack() {
	var base = GameLaunchOptions(displayMode: .windowed, resolution: .hd, usesGameSettings: true)
	base.usesGameMode = true
	base.synchronizationMode = .esync

	for windowSize in GameWindowSizeChoice.allCases.map(WindowSizeAnswer.preset) {
		for rendering in GameRenderingMode.allCases {
			for frameRateLimit in GameFrameRateLimit.allCases {
				let answers = GameDisplayAnswers(
					placement: .window, windowSize: windowSize, rendering: rendering,
					frameRateLimit: frameRateLimit)
				let options = answers.applied(to: base, screen: scaled4K)
				#expect(GameDisplayAnswers(options, screen: scaled4K) == answers)
				#expect(options.windowSize == windowSize.size(on: scaled4K))
				#expect(!options.usesGameSettings)
				#expect(options.usesGameMode)
				#expect(options.synchronizationMode == .esync)
			}
		}
	}
	for rendering in GameRenderingMode.allCases {
		for frameRateLimit in GameFrameRateLimit.allCases {
			// Fullscreen leaves the stored window size alone, so the answer keeps it.
			let answers = GameDisplayAnswers(
				placement: .fullscreen,
				windowSize: WindowSizeAnswer(base.windowSize, on: laptop),
				rendering: rendering, frameRateLimit: frameRateLimit)
			let options = answers.applied(to: base, screen: laptop)
			#expect(GameDisplayAnswers(options, screen: laptop) == answers)
			#expect(options.fullscreenResolution == .native)
		}
	}
	#expect(laptop.fullscreenResolution == .quadHD)
	#expect(scaled4K.fullscreenResolution == .ultraHD)

	let (preferences, _, cleanUp) = makePreferences()
	defer { cleanUp() }
	for answer in PointerAnswer.allCases {
		preferences.pointerAnswer = answer
		#expect(preferences.usesHardwareCursor == (answer == .macPointer))
		#expect(preferences.pointerAnswer == answer)
	}
	preferences.shownLauncherInfo = [.serverTime]
	#expect(!preferences.showsGameVersion)
	#expect(preferences.showsServerResetCountdown)
	#expect(preferences.shownLauncherInfo == [.serverTime])

	for answer in UpdateCheckAnswer.allCases {
		#expect(
			UpdateCheckAnswer(
				launcherChecks: answer.checksForUpdates,
				gameChecks: answer.checksForUpdates,
				announcements: answer.showsAnnouncements
			) == answer
		)
	}
	#expect(UpdateCheckAnswer(launcherChecks: true, gameChecks: false, announcements: true) == nil)
}

@Test(arguments: [
	// A stored size that matches a preset selects that preset.
	(GameWindowSizeChoice.fillScreen.size(on: laptop), WindowSizeAnswer.preset(.fillScreen)),
	(GameWindowSizeChoice.leaveRoom.size(on: laptop), .preset(.leaveRoom)),
	// Any other size, such as one set in Settings, is kept as the custom answer.
	(GameDisplaySize(width: 1000, height: 700), .custom(GameDisplaySize(width: 1000, height: 700))),
])
func storedWindowSizesSelectAPresetOrKeepACustomSize(
	stored: GameDisplaySize, expected: WindowSizeAnswer
) {
	let options = GameLaunchOptions(displayMode: .windowed, resolution: .hd, windowSize: stored)
	let answers = GameDisplayAnswers(options, screen: laptop)
	#expect(answers.windowSize == expected)

	// Changing another answer keeps the stored size.
	var changed = answers
	changed.rendering = .standard
	#expect(changed.applied(to: options, screen: laptop).windowSize == stored)
}
