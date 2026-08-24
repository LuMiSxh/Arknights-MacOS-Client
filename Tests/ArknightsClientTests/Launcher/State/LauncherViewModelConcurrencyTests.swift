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
		model.lifecycle.activity = .runningGame(sessionID: sessionID, processIdentifier: 42)
		model.lifecycle.setStatus(.running)

		model.lifecycle.show(LauncherError.cannotSetAppIcon)

		#expect(model.gameSession.activeGameSessionID == sessionID)
		#expect(model.gameSession.isGameProcessRunning)
		#expect(model.gameSession.canStopGame)
		#expect(model.lifecycle.failureMessage == LauncherError.cannotSetAppIcon.errorDescription)
		await api.resolveBranding()
	}

	@Test
	func activeGameSessionRejectsInstallationAndGameFileMaintenance() async {
		let api = BlockingBrandingAPI()
		let installer = ControllableInstaller()
		let model = makeModel(api: api, installer: installer)
		await api.waitForBrandingRequest()
		model.lifecycle.activity = .runningGame(sessionID: UUID(), processIdentifier: 42)

		model.installation.repairGame()

		#expect(!model.installation.canInstall)
		#expect(!model.installation.canModifyGameFiles)
		#expect(model.gameSession.isGameActive)
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
		model.settings.launchOptions = selectedOptions

		#expect(!model.gameSession.isGameActive)
		model.lifecycle.activity = .preparingGame(sessionID: sessionID)
		#expect(model.gameSession.isGameActive)
		model.resetAllLauncherSettings()
		#expect(model.settings.launchOptions == selectedOptions)
		model.lifecycle.activity = .launchingGame(sessionID: sessionID, processIdentifier: nil)
		#expect(model.gameSession.isGameActive)
		model.lifecycle.activity = .runningGame(sessionID: sessionID, processIdentifier: 42)
		#expect(model.gameSession.isGameActive)
		model.lifecycle.activity = .stoppingGame(sessionID: sessionID, processIdentifier: 42)
		#expect(model.gameSession.isGameActive)
		model.lifecycle.activity = .idle
		#expect(!model.gameSession.isGameActive)

		await api.resolveBranding()
	}

	@Test
	func resettingLauncherSettingsRestoresEveryUserFacingPreference() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		model.settings.automaticallyChecksLauncherUpdates = false
		model.settings.automaticallyChecksGameUpdates = false
		model.settings.announcementsEnabled = false
		model.settings.showsServerResetCountdown = true
		model.settings.showsGameVersion = false
		model.settings.playsLauncherMusic = false
		model.settings.launcherMusicURL = "https://example.com/custom"
		model.settings.showsPlayingMusic = true
		model.settings.launcherMusicVolume = 0.1
		model.settings.usesDynamicTheme = false
		model.settings.launchOptions = GameLaunchOptions(
			displayMode: .fullscreen,
			resolution: .fullHD,
			usesGameSettings: false,
			usesHighResolutionMode: true,
			usesMetalPerformanceHUD: true,
			usesGameMode: true,
			synchronizationMode: .esync
		)

		model.resetAllLauncherSettings()

		#expect(model.settings.automaticallyChecksLauncherUpdates)
		#expect(model.settings.automaticallyChecksGameUpdates)
		#expect(model.settings.announcementsEnabled)
		#expect(!model.settings.showsServerResetCountdown)
		#expect(model.settings.showsGameVersion)
		#expect(model.settings.playsLauncherMusic)
		#expect(model.settings.launcherMusicURL == AppConstants.Music.defaultLauncherMusicURL)
		#expect(!model.settings.showsPlayingMusic)
		#expect(model.settings.launcherMusicVolume == 0.5)
		#expect(model.settings.usesDynamicTheme)
		#expect(model.settings.launchOptions == .default)
		await api.resolveBranding()
	}

	@Test
	func launchRequiresAWorkingIntelTranslationProbe() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequest()
		model.installation.isInstalled = true
		model.gameSession.runtimeName = "Test Runtime"

		model.lifecycle.intelTranslationState = .rosettaMissing
		#expect(!model.gameSession.canLaunch)

		model.lifecycle.intelTranslationState = .gameTestModeEnabled
		#expect(!model.gameSession.canLaunch)

		model.lifecycle.intelTranslationState = .available
		#expect(model.gameSession.canLaunch)

		await api.resolveBranding()
	}

	@Test
	func staleRefreshThatIgnoresCancellationDoesNotHideInstallationProgress() async throws {
		let api = BlockingBrandingAPI()
		let installer = ControllableInstaller()
		let model = makeModel(api: api, installer: installer)

		await api.waitForBrandingRequest()
		model.installation.installOrUpdate()
		await installer.waitForInstallationStart()
		await installer.sendProgress()

		#expect(model.installation.isDownloading)
		#expect(model.lifecycle.phase == .downloading)
		#expect(model.installation.progress?.downloadedBytes == 50)

		await api.resolveBranding()
		await Task.yield()

		#expect(model.installation.isDownloading)
		#expect(model.lifecycle.phase == .downloading)
		#expect(model.installation.progress?.downloadedBytes == 50)

		await installer.completeSuccessfully()
		await waitForDownloadToStop(model)
	}

	@Test
	func secondInstallIsRejectedUntilCancelledInstallerAcknowledgesCancellation() async throws {
		let api = BlockingBrandingAPI()
		let installer = ControllableInstaller()
		let model = makeModel(api: api, installer: installer)

		await api.waitForBrandingRequest()
		model.installation.installOrUpdate()
		await installer.waitForInstallationStart()

		model.installation.installOrUpdate()
		#expect(await installer.installationCount() == 1)

		model.installation.cancelDownload()
		await installer.waitForCancellationRequest()
		model.installation.installOrUpdate()
		#expect(await installer.installationCount() == 1)
		#expect(model.installation.isDownloading)

		await installer.acknowledgeCancellation()
		await waitForDownloadToStop(model)
		#expect(
			model.lifecycle.activityMessage == L10n.string(.Launcher.launcherStatusPaused)
		)
		await api.resolveBranding()
	}

	@Test
	func partialFilesRestoreTheResumableDownloadState() async throws {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequests(1)
		let partial = model.installation.installDirectory.appending(path: "data/game.dat.part")
		try FileManager.default.createDirectory(
			at: partial.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		try Data("partial".utf8).write(to: partial)
		defer { try? FileManager.default.removeItem(at: model.installation.installDirectory) }

		model.installation.updateInstalledState()

		#expect(!model.installation.isInstalled)
		#expect(model.installation.hasPartialDownload)

		try FileManager.default.removeItem(at: partial)
		model.installation.updateInstalledState()
		#expect(!model.installation.hasPartialDownload)
		await api.resolveBranding()
	}

	@Test
	func regionSwitchKeepsCurrentArtworkUntilReplacementLoads() async {
		let api = BlockingBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequests(1)
		let artwork = NSImage(size: NSSize(width: 32, height: 32))
		model.customization.heroArtwork = artwork
		let globalLogo = NSImage(size: NSSize(width: 32, height: 32))
		model.customization.officialLogo = globalLogo

		model.selectRegion(.japan)
		await api.waitForBrandingRequests(2)

		#expect(model.installation.region == .japan)
		#expect(model.customization.heroArtwork === artwork)
		#expect(model.customization.officialLogo == nil)
		await api.resolveBranding()
		let logoLoaded = await waitForCondition { model.customization.officialLogo != nil }
		#expect(logoLoaded)
	}

	@Test
	func customArtworkWinsWhenOfficialArtworkWasAlreadyInFlight() async {
		let directory = FileManager.default.temporaryDirectory.appending(
			path: "BrandingRaceCache.\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		defer { try? FileManager.default.removeItem(at: directory) }
		let configuration = URLSessionConfiguration.ephemeral
		configuration.protocolClasses = [BlockingArtworkURLProtocol.self]
		let cache = ArtworkCache(
			session: URLSession(configuration: configuration),
			directory: directory
		)
		let api = BlockingBrandingAPI()
		let model = makeModel(
			api: api,
			installer: ControllableInstaller(),
			artworkCache: cache
		)
		defer {
			BlockingArtworkURLProtocol.releaseArtwork()
			BlockingArtworkURLProtocol.reset()
		}
		await api.waitForBrandingRequest()

		let branding = LauncherBranding(
			launcherBackgroundImage: URL(string: "https://example.com/japan-artwork.png"),
			launcherBackgroundImageCRC64: "japan-artwork",
			copyrightInformation: nil,
			privacyPolicy: nil,
			userAgreement: nil,
			noticePopOpen: nil,
			noticeContent: nil
		)
		await api.resolveBranding(branding)
		let artworkStarted = await waitForCondition {
			BlockingArtworkURLProtocol.artworkRequestStarted
		}
		#expect(artworkStarted)

		let customData = BlockingArtworkURLProtocol.imageData
		await model.customization.applyDirectCustomArtwork(data: customData)
		BlockingArtworkURLProtocol.releaseArtwork()
		let customArtworkApplied = await waitForCondition {
			model.customization.activeThemeCacheKey?.hasPrefix("custom.") == true
		}
		#expect(customArtworkApplied)
	}

	@Test
	func artworkResetRefreshRemainsTrackedAcrossARegionChange() async {
		let api = CancellableBrandingAPI()
		let model = makeModel(api: api, installer: ControllableInstaller())
		await api.waitForBrandingRequests(1)

		model.resetArtwork()
		await api.waitForCancellations(1)
		await api.waitForBrandingRequests(2)

		model.selectRegion(.japan)
		await api.waitForCancellations(2)
		await api.waitForBrandingRequests(3)
		#expect(model.installation.region == .japan)

		model.refreshController.cancelRefresh()
		await api.waitForCancellations(3)
	}

	@Test
	func onboardingRosettaSimulationDoesNotInvokeTheSystemInstaller() async {
		let installer = RosettaInstallationRecorder(status: 0)
		let model = makeModel(
			api: BlockingBrandingAPI(),
			installer: ControllableInstaller(),
			installRosettaSystemSoftware: { await installer.install() },
			arguments: ["ArknightsClient", "--developer-scenario", "onboarding-rosetta"]
		)

		#expect(model.lifecycle.intelTranslationState == .rosettaMissing)
		#expect(await model.installRosetta() == .available)
		#expect(await installer.count == 0)
	}

}
