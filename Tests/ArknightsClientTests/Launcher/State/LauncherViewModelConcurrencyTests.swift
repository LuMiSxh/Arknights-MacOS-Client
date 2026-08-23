// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherViewModelConcurrencyTests {
	@Test
	func presentationFailureDoesNotOverwriteRunningGameLifecycle() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		let sessionID = UUID()
		model.state.activity = .runningGame(sessionID: sessionID, processIdentifier: 42)
		model.setStatus(.running)

		model.show(LauncherError.cannotSetAppIcon)

		#expect(model.activeGameSessionID == sessionID)
		#expect(model.isGameProcessRunning)
		#expect(model.canStopGame)
		#expect(model.failureMessage == LauncherError.cannotSetAppIcon.errorDescription)
		await api.resolveBranding()
	}

	@Test
	func activeGameSessionRejectsInstallationAndGameFileMaintenance() async {
		let api = BlockingBrandingAPI()
		let installer = ControllableInstaller()
		let model = makeModel(api: api, installer: installer)
		await api.waitForBrandingRequest()
		model.state.activity = .runningGame(sessionID: UUID(), processIdentifier: 42)

		model.repairGame()

		#expect(!model.canInstall)
		#expect(!model.canModifyGameFiles)
		#expect(!model.canModifyLaunchOptions)
		#expect(await installer.installationCount() == 0)
		await api.resolveBranding()
	}

	@Test
	func launchOptionsStayLockedForTheEntireGameSession() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		let sessionID = UUID()
		let selectedOptions = GameLaunchOptions(
			displayMode: .fullscreen,
			resolution: .quadHD,
			usesGameSettings: false,
			usesHighResolutionMode: false,
			usesMetalPerformanceHUD: true,
			usesGameMode: true,
			synchronizationMode: .esync
		)
		model.launchOptions = selectedOptions

		#expect(model.canModifyLaunchOptions)
		model.state.activity = .preparingGame(sessionID: sessionID)
		#expect(!model.canModifyLaunchOptions)
		model.resetAllLauncherSettings()
		#expect(model.launchOptions == selectedOptions)
		model.state.activity = .launchingGame(sessionID: sessionID, processIdentifier: nil)
		#expect(!model.canModifyLaunchOptions)
		model.state.activity = .runningGame(sessionID: sessionID, processIdentifier: 42)
		#expect(!model.canModifyLaunchOptions)
		model.state.activity = .stoppingGame(sessionID: sessionID, processIdentifier: 42)
		#expect(!model.canModifyLaunchOptions)
		model.state.activity = .idle
		#expect(model.canModifyLaunchOptions)

		await api.resolveBranding()
	}

	@Test
	func resettingLauncherSettingsRestoresEveryUserFacingPreference() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		model.automaticallyChecksLauncherUpdates = false
		model.automaticallyChecksGameUpdates = false
		model.announcementsEnabled = false
		model.showsServerResetCountdown = true
		model.showsGameVersion = false
		model.playsLauncherMusic = false
		model.launcherMusicURL = "https://example.com/custom"
		model.showsPlayingMusic = true
		model.launcherMusicVolume = 0.1
		model.usesDynamicTheme = false
		model.launchOptions = GameLaunchOptions(
			displayMode: .fullscreen,
			resolution: .fullHD,
			usesGameSettings: false,
			usesHighResolutionMode: true,
			usesMetalPerformanceHUD: true,
			usesGameMode: true,
			synchronizationMode: .esync
		)

		model.resetAllLauncherSettings()

		#expect(model.automaticallyChecksLauncherUpdates)
		#expect(model.automaticallyChecksGameUpdates)
		#expect(model.announcementsEnabled)
		#expect(!model.showsServerResetCountdown)
		#expect(model.showsGameVersion)
		#expect(model.playsLauncherMusic)
		#expect(model.launcherMusicURL == AppConstants.Music.defaultLauncherMusicURL)
		#expect(!model.showsPlayingMusic)
		#expect(model.launcherMusicVolume == 0.5)
		#expect(model.usesDynamicTheme)
		#expect(model.launchOptions == .default)
		await api.resolveBranding()
	}

	@Test
	func launchRequiresAWorkingIntelTranslationProbe() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		model.isInstalled = true
		model.runtimeName = "Test Runtime"

		model.intelTranslationState = .rosettaMissing
		#expect(!model.canLaunch)

		model.intelTranslationState = .gameTestModeEnabled
		#expect(!model.canLaunch)

		model.intelTranslationState = .available
		#expect(model.canLaunch)

		await api.resolveBranding()
		await Task.yield()
	}

	@Test
	func successfulRosettaInstallationRepeatsTheFunctionalProbe() async {
		let api = BlockingBrandingAPI()
		let checks = TranslationCheckSequence(states: [.rosettaMissing, .available])
		let installer = RosettaInstallationRecorder(status: 0)
		let model = makeModel(
			api: api,
			installer: ControllableInstaller(),
			checkIntelTranslation: { await checks.next() },
			installRosettaSystemSoftware: { await installer.install() }
		)
		await api.waitForBrandingRequest()
		#expect(model.intelTranslationState == .rosettaMissing)

		let state = await model.installRosetta()

		#expect(state == .available)
		#expect(model.intelTranslationState == .available)
		#expect(model.rosettaInstallationState == .idle)
		#expect(await checks.count == 2)
		#expect(await installer.count == 1)
		await api.resolveBranding()
	}

	@Test
	func failedRosettaInstallationKeepsLaunchBlockedAndExposesRecovery() async {
		let api = BlockingBrandingAPI()
		let checks = TranslationCheckSequence(states: [.rosettaMissing])
		let installer = RosettaInstallationRecorder(status: 7)
		let model = makeModel(
			api: api,
			installer: ControllableInstaller(),
			checkIntelTranslation: { await checks.next() },
			installRosettaSystemSoftware: { await installer.install() }
		)
		await api.waitForBrandingRequest()

		let state = await model.installRosetta()

		#expect(state == .rosettaMissing)
		#expect(!model.canLaunch)
		#expect(
			model.rosettaInstallationState.failureMessage
				== L10n.string(.Launcher.launcherRosettaFailureInstallerExited("7"))
		)
		#expect(
			model.rosettaInstallationActionTitle
				== L10n.string(.Launcher.launcherRosettaActionInstallAgain)
		)
		#expect(await checks.count == 1)
		await api.resolveBranding()
	}

	@Test
	func staleRefreshThatIgnoresCancellationDoesNotHideInstallationProgress() async throws {
		let api = BlockingBrandingAPI()
		let installer = ControllableInstaller()
		let model = makeModel(api: api, installer: installer)

		await api.waitForBrandingRequest()
		model.installOrUpdate()
		await installer.waitForInstallationStart()
		await installer.sendProgress()

		#expect(model.isDownloading)
		#expect(model.phase == .downloading)
		#expect(model.progress?.downloadedBytes == 50)

		await api.resolveBranding()
		await Task.yield()

		#expect(model.isDownloading)
		#expect(model.phase == .downloading)
		#expect(model.progress?.downloadedBytes == 50)

		await installer.completeSuccessfully()
		await waitForDownloadToStop(model)
	}

	@Test
	func secondInstallIsRejectedUntilCancelledInstallerAcknowledgesCancellation() async throws {
		let api = BlockingBrandingAPI()
		let installer = ControllableInstaller()
		let model = makeModel(api: api, installer: installer)

		await api.waitForBrandingRequest()
		model.installOrUpdate()
		await installer.waitForInstallationStart()

		model.installOrUpdate()
		#expect(await installer.installationCount() == 1)

		model.cancelDownload()
		await installer.waitForCancellationRequest()
		model.installOrUpdate()
		#expect(await installer.installationCount() == 1)
		#expect(model.isDownloading)

		await installer.acknowledgeCancellation()
		await waitForDownloadToStop(model)
		#expect(model.activityMessage == L10n.string(.Launcher.launcherStatusPaused))
		await api.resolveBranding()
	}

	@Test
	func queuedPopupsAreRecordedOnlyWhenTheyBecomeVisible() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequests(1)
		let popup: (String) -> LauncherPopup = { id in
			LauncherPopup(
				id: id,
				title: "Test",
				content: .markdown("Test"),
				dismissTitle: "Done",
				actionTitle: nil,
				actionURL: nil
			)
		}

		model.enqueuePopup(popup("official-notice"))
		model.enqueuePopup(popup("announcement-feedback"))
		model.enqueuePopup(popup("launcher-update-0.2.0"))

		#expect(!model.preferences.seenAnnouncementIDs().contains("feedback"))
		#expect(model.preferences.presentedLauncherUpdate() == nil)

		model.dismissPopup()
		#expect(model.preferences.seenAnnouncementIDs().contains("feedback"))
		#expect(model.preferences.presentedLauncherUpdate() == nil)

		model.dismissPopup()
		#expect(model.preferences.presentedLauncherUpdate() == "0.2.0")
		await api.resolveBranding()
	}

	@Test
	func partialFilesRestoreTheResumableDownloadState() async throws {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequests(1)
		let partial = model.installDirectory.appending(path: "data/game.dat.part")
		try FileManager.default.createDirectory(
			at: partial.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		try Data("partial".utf8).write(to: partial)
		defer { try? FileManager.default.removeItem(at: model.installDirectory) }

		model.updateInstalledState()

		#expect(!model.isInstalled)
		#expect(model.hasPartialDownload)

		try FileManager.default.removeItem(at: partial)
		model.updateInstalledState()
		#expect(!model.hasPartialDownload)
		await api.resolveBranding()
	}

	@Test
	func regionSwitchKeepsCurrentArtworkUntilReplacementLoads() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequests(1)
		let artwork = NSImage(size: NSSize(width: 32, height: 32))
		model.heroArtwork = artwork

		model.selectRegion(.japan)
		await api.waitForBrandingRequests(2)

		#expect(model.region == .japan)
		#expect(model.heroArtwork === artwork)
		await api.resolveBranding()
	}

	@Test
	func unchangedArtworkIdentityKeepsThePresentedImageInstance() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		let visibleArtwork = NSImage(size: NSSize(width: 32, height: 32))
		let duplicateDecode = NSImage(size: NSSize(width: 32, height: 32))
		let replacementArtwork = NSImage(size: NSSize(width: 32, height: 32))

		model.setHeroArtwork(visibleArtwork, themeCacheKey: "official.global.first")
		model.setHeroArtwork(duplicateDecode, themeCacheKey: "official.global.first")
		#expect(model.heroArtwork === visibleArtwork)

		model.setHeroArtwork(replacementArtwork, themeCacheKey: "official.global.second")
		#expect(model.heroArtwork === replacementArtwork)

		await api.waitForBrandingRequest()
		await api.resolveBranding()
	}

}
