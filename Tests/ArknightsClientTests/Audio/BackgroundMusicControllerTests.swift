// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing
import YouTubePlayerKit

@testable import ArknightsClient

@MainActor
struct BackgroundMusicControllerTests {
	@Test
	func trackNavigationIsAvailableOnlyForPlaylists() {
		let (controller, _, defaults, suiteName) = makeController()
		defer { defaults.removePersistentDomain(forName: suiteName) }

		controller.currentSource = .video(id: "one")
		#expect(!controller.canNavigatePlaylist)

		controller.currentSource = .playlist(id: "many")
		#expect(controller.canNavigatePlaylist)
	}

	@Test
	func bufferingCountsAsActivePlaybackForThePauseControl() {
		let (controller, _, defaults, suiteName) = makeController()
		defer { defaults.removePersistentDomain(forName: suiteName) }

		controller.playbackState = .paused
		#expect(!controller.isPlaying)

		controller.playbackState = .buffering
		#expect(controller.isPlaying)

		controller.playbackState = .playing
		#expect(controller.isPlaying)
	}

	@Test
	func playbackIntentImmediatelyDrivesControlsUntilPlayerConfirmsIt() {
		let (controller, _, defaults, suiteName) = makeController()
		defer { defaults.removePersistentDomain(forName: suiteName) }

		controller.playbackState = .playing
		controller.playbackIntent = .paused
		controller.isChangingPlayback = true
		#expect(!controller.isPlaying)
		#expect(controller.controlsAreDisabled)

		controller.playbackState = .paused
		controller.reconcilePlaybackIntent(with: .paused)
		#expect(controller.playbackIntent == nil)
		#expect(!controller.isChangingPlayback)
		#expect(!controller.isPlaying)
	}

	@Test
	func playlistNavigationWrapsAndSkipsDuplicateEntries() {
		let playlist = ["first", "first", "middle", "last"]

		#expect(TrackDirection.next.targetIndex(in: playlist, currentIndex: 0) == 2)
		#expect(TrackDirection.previous.targetIndex(in: playlist, currentIndex: 0) == 3)
		#expect(TrackDirection.next.targetIndex(in: playlist, currentIndex: 3) == 0)
		#expect(TrackDirection.previous.targetIndex(in: playlist, currentIndex: 2) == 1)
		#expect(TrackDirection.next.targetIndex(in: ["same", "same"], currentIndex: 0) == nil)
		#expect(TrackDirection.next.targetIndex(in: playlist, currentIndex: 20) == nil)
	}

	@Test
	func repeatedTitleStillUpdatesTheCurrentVideoIdentifier() {
		let (controller, model, defaults, suiteName) = makeController()
		defer { defaults.removePersistentDomain(forName: suiteName) }

		#expect(
			controller.applyTrackTitle(
				from: .init(title: "Chase the Light", videoId: "first")
			)
		)
		#expect(
			controller.applyTrackTitle(
				from: .init(title: "Chase the Light", videoId: "second")
			)
		)

		#expect(model.currentMusicTitle == "Chase the Light")
		#expect(model.currentMusicVideoID == "second")
		#expect(controller.lastObservedVideoID == "second")
	}

	@Test
	func initialShuffleAcceptsANewVideoAtTheSelectedIndex() {
		#expect(
			BackgroundMusicController.hasReachedSelectedVideo(
				previousVideoID: "first",
				expectedVideoID: "snapshot-second",
				observedVideoID: "reshuffled-second"
			)
		)
		#expect(
			!BackgroundMusicController.hasReachedSelectedVideo(
				previousVideoID: "first",
				expectedVideoID: "snapshot-second",
				observedVideoID: "first"
			)
		)
		#expect(
			!BackgroundMusicController.hasReachedSelectedVideo(
				previousVideoID: "first",
				expectedVideoID: "snapshot-second",
				observedVideoID: nil
			)
		)
	}

	@Test
	func mutePreservesTheConfiguredVolumeAndRestoresIt() {
		let (controller, model, defaults, suiteName) = makeController()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		model.launcherMusicVolume = 0.7

		controller.toggleMute()

		#expect(controller.isMuted)
		#expect(controller.effectiveVolume == 0)
		#expect(model.launcherMusicVolume == 0.7)
		#expect(model.preferences.launcherMusicVolume() == 0.7)

		controller.toggleMute()

		#expect(!controller.isMuted)
		#expect(controller.effectiveVolume == 0.7)
	}

	@Test
	func volumeChangesWhileMutedBecomeTheNextAudibleLevel() {
		let (controller, model, defaults, suiteName) = makeController()
		defer { defaults.removePersistentDomain(forName: suiteName) }
		controller.toggleMute()

		model.launcherMusicVolume = 0.25

		#expect(controller.effectiveVolume == 0)
		controller.toggleMute()
		#expect(controller.effectiveVolume == 0.25)
	}

	private func makeController() -> (
		BackgroundMusicController, LauncherViewModel, UserDefaults, String
	) {
		let identifier = "BackgroundMusicControllerTests.\(UUID().uuidString)"
		let root = URL(filePath: NSTemporaryDirectory()).appending(
			path: identifier,
			directoryHint: .isDirectory
		)
		let defaults = UserDefaults(suiteName: identifier)!
		let preferences = LauncherPreferencesStore(defaults: defaults)
		preferences.setAutomaticGameUpdates(false)
		preferences.setAutomaticLauncherUpdates(false)
		preferences.setAnnouncementsEnabled(false)
		let model = LauncherViewModel(
			paths: AppPaths(
				applicationSupportDirectory: root.appending(path: "Support"),
				cachesDirectory: root.appending(path: "Caches"),
				libraryDirectory: root.appending(path: "Library")
			),
			preferences: preferences,
			checkIntelTranslation: {
				IntelTranslationCheck(state: .available, diagnostics: "test")
			},
			arguments: ["--developer-scenario", "ready"]
		)
		return (BackgroundMusicController(context: model), model, defaults, identifier)
	}
}
