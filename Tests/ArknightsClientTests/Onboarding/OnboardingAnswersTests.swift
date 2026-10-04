// SPDX-License-Identifier: MPL-2.0

import CoreGraphics
import Testing

@testable import ArknightsClient

private let laptop = GameScreenMetrics(
	visibleSize: CGSize(width: 1470, height: 919), pixelSize: CGSize(width: 2940, height: 1912))
private let scaled4K = GameScreenMetrics(
	visibleSize: CGSize(width: 3008, height: 1659), pixelSize: CGSize(width: 6016, height: 3384))

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
	#expect(smooth.renderingMode == .metalFX && smooth.windowSize == window.windowSize)
	#expect(fullscreen.displayMode == .fullscreen && fullscreen.fullscreenResolution == .native)
	#expect(fullscreen.resolution == .ultraHD)
}

@Test(arguments: GamePlacementAnswer.allCases, GameRenderingMode.allCases)
func appliedDisplayAnswersAreReadBack(placement: GamePlacementAnswer, rendering: GameRenderingMode)
{
	let answers = GameDisplayAnswers(placement: placement, rendering: rendering)
	let base = GameLaunchOptions(displayMode: .windowed, resolution: .hd, usesGameSettings: true)

	#expect(GameDisplayAnswers(answers.applied(to: base, screen: laptop)) == answers)
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
