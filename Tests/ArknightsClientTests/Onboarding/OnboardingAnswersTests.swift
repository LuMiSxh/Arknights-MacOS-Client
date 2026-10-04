// SPDX-License-Identifier: MPL-2.0

import CoreGraphics
import Foundation
import Testing

@testable import ArknightsClient

private let laptop = GameScreenMetrics(
	visibleSize: CGSize(width: 1470, height: 919), pixelSize: CGSize(width: 2940, height: 1912))
private let scaled4K = GameScreenMetrics(
	visibleSize: CGSize(width: 3008, height: 1659), pixelSize: CGSize(width: 6016, height: 3384))

@MainActor
private func makePreferences() -> (
	LauncherPreferencesController, LauncherPreferencesStore, () -> Void
) {
	let suiteName = "OnboardingAnswersTests.\(UUID().uuidString)"
	let defaults = UserDefaults(suiteName: suiteName)!
	let store = LauncherPreferencesStore(defaults: defaults)
	return (
		LauncherPreferencesController(store: store), store,
		{ defaults.removePersistentDomain(forName: suiteName) }
	)
}

@Test(arguments: [(laptop, GameResolution.quadHD), (scaled4K, .ultraHD)])
func screenMetricsPickTheLargestFittingResolution(
	screen: GameScreenMetrics, resolution: GameResolution
) {
	#expect(screen.fullscreenResolution == resolution)
}

@Test
func displayAnswersLetTheLauncherSizeTheGameAndKeepUnrelatedOptions() {
	var base = GameLaunchOptions.default
	base.usesGameSettings = true
	base.usesGameMode = true
	base.synchronizationMode = .esync

	let window = GameDisplayAnswers.recommended.applied(to: base, screen: scaled4K)
	let smooth = GameDisplayAnswers(placement: .window, rendering: .metalFX)
		.applied(to: base, screen: scaled4K)
	let fullscreen = GameDisplayAnswers(placement: .fullscreen, rendering: .retina)
		.applied(to: base, screen: scaled4K)

	for options in [window, smooth, fullscreen] {
		#expect(!options.usesGameSettings)
		#expect(options.usesGameMode)
		#expect(options.synchronizationMode == .esync)
	}
	#expect(window.displayMode == .windowed && window.renderingMode == .retina)
	#expect(window.windowSize == GameDisplaySize(width: 3008, height: 1631))
	#expect(window.windowSize == GameWindowSizeChoice.fillScreen.size(on: scaled4K))
	#expect(smooth.renderingMode == .metalFX && smooth.windowSize == window.windowSize)
	#expect(fullscreen.displayMode == .fullscreen && fullscreen.fullscreenResolution == .native)
	#expect(fullscreen.resolution == .ultraHD)
}

@Test
func windowedAnswersUseTheChosenWindowSize() {
	let leaveRoom = GameDisplayAnswers(
		placement: .window, windowSize: .leaveRoom, rendering: .retina
	).applied(to: .default, screen: scaled4K)

	#expect(leaveRoom.windowSize == GameWindowSizeChoice.leaveRoom.size(on: scaled4K))
	#expect(leaveRoom.windowSize != GameWindowSizeChoice.fillScreen.size(on: scaled4K))
}

@Test(arguments: GameWindowSizeChoice.allCases, GameRenderingMode.allCases)
func appliedWindowAnswersAreReadBack(
	windowSize: GameWindowSizeChoice, rendering: GameRenderingMode
) {
	let answers = GameDisplayAnswers(
		placement: .window, windowSize: windowSize, rendering: rendering)
	let base = GameLaunchOptions(displayMode: .windowed, resolution: .hd, usesGameSettings: true)

	#expect(
		GameDisplayAnswers(answers.applied(to: base, screen: laptop), screen: laptop) == answers)
}

@Test(arguments: GameRenderingMode.allCases)
func appliedFullscreenAnswersAreReadBack(rendering: GameRenderingMode) {
	let answers = GameDisplayAnswers(placement: .fullscreen, rendering: rendering)
	let base = GameLaunchOptions(displayMode: .windowed, resolution: .hd, usesGameSettings: true)

	#expect(
		GameDisplayAnswers(answers.applied(to: base, screen: laptop), screen: laptop).placement
			== .fullscreen)
	#expect(
		GameDisplayAnswers(answers.applied(to: base, screen: laptop), screen: laptop).rendering
			== rendering)
}

@Test
func handSizedWindowsReadBackAsFillingTheScreen() {
	var options = GameLaunchOptions.default
	options.windowSize = GameDisplaySize(width: 1000, height: 700)

	#expect(GameDisplayAnswers(options, screen: laptop).windowSize == .fillScreen)
}

@MainActor
@Test(arguments: PointerAnswer.allCases)
func pointerAnswersWriteTheHardwareCursorPreference(answer: PointerAnswer) {
	let (preferences, store, cleanUp) = makePreferences()
	defer { cleanUp() }

	preferences.pointerAnswer = answer

	#expect(preferences.usesHardwareCursor == (answer == .macPointer))
	#expect(store.usesHardwareCursor() == (answer == .macPointer))
	#expect(preferences.pointerAnswer == answer)
}

@MainActor
@Test
func launcherInfoAnswersMapToTheTwoDisplayPreferences() {
	let (preferences, _, cleanUp) = makePreferences()
	defer { cleanUp() }

	preferences.shownLauncherInfo = [.gameVersion]
	#expect(preferences.showsGameVersion)
	#expect(!preferences.showsServerResetCountdown)

	preferences.shownLauncherInfo = [.serverTime]
	#expect(!preferences.showsGameVersion)
	#expect(preferences.showsServerResetCountdown)
	#expect(preferences.shownLauncherInfo == [.serverTime])

	preferences.shownLauncherInfo = []
	#expect(!preferences.showsGameVersion)
	#expect(!preferences.showsServerResetCountdown)
}

@Test(arguments: UpdateCheckAnswer.allCases)
func updateAnswersAreReadBackFromTheirPreferences(answer: UpdateCheckAnswer) {
	#expect(
		UpdateCheckAnswer(
			launcherChecks: answer.checksForUpdates,
			gameChecks: answer.checksForUpdates,
			announcements: answer.showsAnnouncements
		) == answer
	)
}

@Test
func customizedUpdatePreferencesMatchNoAnswer() {
	#expect(UpdateCheckAnswer(launcherChecks: true, gameChecks: false, announcements: true) == nil)
	#expect(UpdateCheckAnswer(launcherChecks: true, gameChecks: true, announcements: false) == nil)
}
