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

	for windowSize in GameWindowSizeChoice.allCases {
		for rendering in GameRenderingMode.allCases {
			let answers = GameDisplayAnswers(
				placement: .window, windowSize: windowSize, rendering: rendering)
			let options = answers.applied(to: base, screen: scaled4K)
			#expect(GameDisplayAnswers(options, screen: scaled4K) == answers)
			#expect(options.windowSize == windowSize.size(on: scaled4K))
			#expect(!options.usesGameSettings)
			#expect(options.usesGameMode)
			#expect(options.synchronizationMode == .esync)
		}
	}
	for rendering in GameRenderingMode.allCases {
		let answers = GameDisplayAnswers(placement: .fullscreen, rendering: rendering)
		let options = answers.applied(to: base, screen: laptop)
		#expect(GameDisplayAnswers(options, screen: laptop) == answers)
		#expect(options.fullscreenResolution == .native)
	}
	#expect(laptop.fullscreenResolution == .quadHD)
	#expect(scaled4K.fullscreenResolution == .ultraHD)

	var handSized = GameLaunchOptions.default
	handSized.windowSize = GameDisplaySize(width: 1000, height: 700)
	#expect(GameDisplayAnswers(handSized, screen: laptop).windowSize == .fillScreen)

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
