// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherViewModelConcurrencyTests {
	@Test
	func stopIsEnabledOnlyForRunningGamePhase() {
		#expect(
			!LauncherViewModel.canStopGame(
				for: .launching,
				hasActiveSession: true,
				isStoppingGame: false
			))
		#expect(
			LauncherViewModel.canStopGame(
				for: .running(processIdentifier: 42),
				hasActiveSession: true,
				isStoppingGame: false
			))
		#expect(
			!LauncherViewModel.canStopGame(
				for: .running(processIdentifier: 42),
				hasActiveSession: true,
				isStoppingGame: true
			))
		#expect(
			!LauncherViewModel.canStopGame(
				for: .running(processIdentifier: 42),
				hasActiveSession: false,
				isStoppingGame: false
			))
	}

	@Test
	func directWineProcessExitTracksStartupAndRunningSessions() {
		#expect(
			LauncherViewModel.directWineProcessExitAction(
				for: 1,
				phase: .launching,
				hasActiveSession: true
			) == .startupFailure)
		#expect(
			LauncherViewModel.directWineProcessExitAction(
				for: 0,
				phase: .launching,
				hasActiveSession: true
			) == .startupFailure)
		#expect(
			LauncherViewModel.directWineProcessExitAction(
				for: 1,
				phase: .running(processIdentifier: 42),
				hasActiveSession: true
			) == .gameExited)
		#expect(
			LauncherViewModel.directWineProcessExitAction(
				for: 0,
				phase: .running(processIdentifier: 42),
				hasActiveSession: true
			) == .gameExited)
		#expect(
			LauncherViewModel.directWineProcessExitAction(
				for: 1,
				phase: .launching,
				hasActiveSession: false
			) == .ignore)
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
		#expect(model.activityMessage == "Paused")
	}

	@Test
	func queuedPopupsAreRecordedOnlyWhenTheyBecomeVisible() {
		let model = makeModel(api: BlockingBrandingAPI(), installer: ControllableInstaller())
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
	}

	@Test
	func partialFilesRestoreTheResumableDownloadState() throws {
		let model = makeModel(api: BlockingBrandingAPI(), installer: ControllableInstaller())
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
	}

	private func waitForDownloadToStop(_ model: LauncherViewModel) async {
		for _ in 0..<100 where model.isDownloading {
			await Task.yield()
		}
		#expect(!model.isDownloading)
	}

	private func makeModel(
		api: some LauncherAPIProviding,
		installer: some GameInstalling
	) -> LauncherViewModel {
		let root = URL(filePath: NSTemporaryDirectory())
			.appending(
				path: "LauncherViewModelConcurrencyTests.\(UUID().uuidString)",
				directoryHint: .isDirectory)
		let paths = AppPaths(
			applicationSupportDirectory: root.appending(
				path: "Support", directoryHint: .isDirectory),
			cachesDirectory: root.appending(path: "Caches", directoryHint: .isDirectory),
			libraryDirectory: root.appending(path: "Library", directoryHint: .isDirectory)
		)
		let defaults = UserDefaults(
			suiteName: "LauncherViewModelConcurrencyTests.\(UUID().uuidString)")!
		let preferences = LauncherPreferencesStore(defaults: defaults)
		preferences.setAutomaticGameUpdates(false)
		preferences.setAutomaticLauncherUpdates(false)
		return LauncherViewModel(
			api: api,
			installer: installer,
			paths: paths,
			preferences: preferences,
			arguments: []
		)
	}
}

private actor BlockingBrandingAPI: LauncherAPIProviding {
	private var brandingRequested = false
	private var brandingRequestWaiters: [CheckedContinuation<Void, Never>] = []
	private var brandingResponse: CheckedContinuation<LauncherBranding, Never>?

	func gameConfiguration() async throws -> GameConfiguration {
		GameConfiguration(
			gameLowestVersion: "1.0.0",
			gameLatestVersion: "2.0.0",
			gameLatestFilePath: "game.zip",
			gameStartExeName: "Arknights",
			gameStartParams: [],
			gameUninstallScript: "uninstall.exe",
			decompressionSize: "1 GB"
		)
	}

	func branding() async throws -> LauncherBranding {
		brandingRequested = true
		for waiter in brandingRequestWaiters {
			waiter.resume()
		}
		brandingRequestWaiters.removeAll()
		return await withCheckedContinuation { brandingResponse = $0 }
	}

	func cdnConfiguration() async throws -> CDNConfiguration { throw CancellationError() }

	func manifest(for configuration: GameConfiguration) async throws -> GameManifest {
		throw CancellationError()
	}

	func waitForBrandingRequest() async {
		guard !brandingRequested else { return }
		await withCheckedContinuation { brandingRequestWaiters.append($0) }
	}

	func resolveBranding() {
		let branding = LauncherBranding(
			launcherBackgroundImage: nil,
			launcherBackgroundImageCRC64: nil,
			copyrightInformation: nil,
			privacyPolicy: nil,
			userAgreement: nil,
			noticePopOpen: nil,
			noticeContent: nil
		)
		brandingResponse?.resume(returning: branding)
		brandingResponse = nil
	}
}

private actor ControllableInstaller: GameInstalling {
	private var count = 0
	private var installationStarted = false
	private var cancellationRequested = false
	private var installationStartWaiters: [CheckedContinuation<Void, Never>] = []
	private var cancellationRequestWaiters: [CheckedContinuation<Void, Never>] = []
	private var installationResponse: CheckedContinuation<InstallResult, Error>?
	private var progress: (@Sendable (DownloadProgress) async -> Void)?

	func install(
		configuration: GameConfiguration,
		into installDirectory: URL,
		verifyAllExistingFiles: Bool,
		progress: @escaping @Sendable (DownloadProgress) async -> Void
	) async throws -> InstallResult {
		count += 1
		self.progress = progress
		return try await withTaskCancellationHandler {
			try await withCheckedThrowingContinuation { continuation in
				installationResponse = continuation
				installationStarted = true
				for waiter in installationStartWaiters {
					waiter.resume()
				}
				installationStartWaiters.removeAll()
			}
		} onCancel: {
			Task { await self.recordCancellationRequest() }
		}
	}

	func installationCount() -> Int { count }

	func waitForInstallationStart() async {
		guard !installationStarted else { return }
		await withCheckedContinuation { installationStartWaiters.append($0) }
	}

	func waitForCancellationRequest() async {
		guard !cancellationRequested else { return }
		await withCheckedContinuation { cancellationRequestWaiters.append($0) }
	}

	func sendProgress() async {
		await progress?(
			DownloadProgress(
				downloadedBytes: 50,
				totalBytes: 100,
				completedFiles: 1,
				totalFiles: 2,
				currentFile: "game.zip"
			))
	}

	func acknowledgeCancellation() {
		installationResponse?.resume(throwing: CancellationError())
		installationResponse = nil
	}

	func completeSuccessfully() {
		installationResponse?.resume(
			returning: InstallResult(
				downloadedFiles: 1,
				downloadedBytes: 100,
				installDirectory: URL(filePath: "/tmp/Arknights-Global")
			)
		)
		installationResponse = nil
	}

	private func recordCancellationRequest() {
		cancellationRequested = true
		for waiter in cancellationRequestWaiters {
			waiter.resume()
		}
		cancellationRequestWaiters.removeAll()
	}
}
