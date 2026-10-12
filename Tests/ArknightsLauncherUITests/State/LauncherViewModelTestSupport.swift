// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsCustomization
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameInstallation
@testable import ArknightsGameRuntime
@testable import ArknightsLauncherUI

@MainActor
func waitForDownloadToStop(_ model: LauncherViewModel) async {
	#expect(await waitForCondition { !model.installation.isDownloading })
}

@MainActor
func makeModel(
	api: some LauncherAPIProviding,
	installer: some GameInstalling,
	artworkCache: ArtworkCache? = nil,
	checkIntelTranslation: @escaping @Sendable () async -> IntelTranslationCheck = {
		IntelTranslationCheck(state: .available, diagnostics: "test")
	},
	installRosettaSystemSoftware:
		@escaping @Sendable () async throws
		-> IntelTranslationProcessResult = {
			IntelTranslationProcessResult(status: 0, output: "test")
		},
	arguments: [String] = [],
	prepareStorage: ((AppPaths) -> Void)? = nil
) -> LauncherViewModel {
	let root = URL(filePath: NSTemporaryDirectory())
		.appending(
			path: "LauncherViewModelTests.\(UUID().uuidString)",
			directoryHint: .isDirectory)
	let paths = AppPaths(
		applicationSupportDirectory: root.appending(
			path: "Support", directoryHint: .isDirectory),
		cachesDirectory: root.appending(path: "Caches", directoryHint: .isDirectory),
		libraryDirectory: root.appending(path: "Library", directoryHint: .isDirectory)
	)
	prepareStorage?(paths)
	let defaults = UserDefaults(suiteName: "LauncherViewModelTests.\(UUID().uuidString)")!
	let preferences = LauncherPreferencesStore(defaults: defaults)
	preferences.set(false, for: LauncherPreferencesStore.Key.automaticGameUpdates)
	preferences.set(false, for: LauncherPreferencesStore.Key.automaticLauncherUpdates)
	preferences.set(false, for: LauncherPreferencesStore.Key.announcementsEnabled)
	let resolvedArtworkCache =
		artworkCache
		?? ArtworkCache(session: testArtworkSession(), directory: paths.artworkCache)
	return LauncherViewModel(
		api: api,
		installer: installer,
		paths: paths,
		artworkCache: resolvedArtworkCache,
		preferences: preferences,
		checkIntelTranslation: checkIntelTranslation,
		installRosettaSystemSoftware: installRosettaSystemSoftware,
		arguments: arguments
	)
}

private func testArtworkSession() -> URLSession {
	let imageData = Data(
		base64Encoded:
			"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zf9sAAAAASUVORK5CYII="
	)!
	let route = StubURLProtocol.Route()
	route.handler = { request in
		(
			HTTPURLResponse(
				url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
			imageData
		)
	}
	return route.session
}

typealias BlockingBrandingAPI = CancellableBrandingAPI

actor ControllableInstaller: GameInstalling {
	private var count = 0
	private var regions: [GameRegion] = []
	private var verificationModes: [Bool] = []
	private var installationStarted = false
	private var cancellationRequested = false
	private var installationStartWaiters: [CheckedContinuation<Void, Never>] = []
	private var cancellationRequestWaiters: [CheckedContinuation<Void, Never>] = []
	private var installationResponse: CheckedContinuation<InstallResult, Error>?
	private var progress: (@Sendable (DownloadProgress) async -> Void)?
	func install(
		configuration: GameConfiguration,
		region: GameRegion,
		into installDirectory: URL,
		verifyAllExistingFiles: Bool,
		progress: @escaping @Sendable (DownloadProgress) async -> Void
	) async throws -> InstallResult {
		count += 1
		regions.append(region)
		verificationModes.append(verifyAllExistingFiles)
		self.progress = progress
		return try await withTaskCancellationHandler {
			try await withCheckedThrowingContinuation { continuation in
				if cancellationRequested {
					continuation.resume(throwing: CancellationError())
					return
				}
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
	func requestedRegions() -> [GameRegion] { regions }
	func requestedVerificationModes() -> [Bool] { verificationModes }
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
		let response = installationResponse
		installationResponse = nil
		response?.resume(throwing: CancellationError())
	}
}

actor CancellableBrandingAPI: LauncherAPIProviding {
	private var brandingRequests = 0
	private var requestWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
	private var brandingContinuations:
		[(id: Int, continuation: CheckedContinuation<LauncherBranding, Error>)] = []
	private var cancelledBrandingRequestIDs: Set<Int> = []

	func gameConfiguration(region: GameRegion) async throws -> GameConfiguration {
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

	func branding(region: GameRegion) async throws -> LauncherBranding {
		brandingRequests += 1
		let requestID = brandingRequests
		resumeReadyWaiters()
		return try await withTaskCancellationHandler {
			try await withCheckedThrowingContinuation { continuation in
				if cancelledBrandingRequestIDs.remove(requestID) != nil {
					continuation.resume(throwing: CancellationError())
				} else {
					brandingContinuations.append((id: requestID, continuation: continuation))
				}
			}
		} onCancel: {
			Task { await self.cancelBrandingRequest(id: requestID) }
		}
	}

	func cdnConfiguration(region: GameRegion) async throws -> CDNConfiguration {
		throw CancellationError()
	}

	func manifest(
		for configuration: GameConfiguration,
		region: GameRegion
	) async throws -> GameManifest {
		throw CancellationError()
	}

	func waitForBrandingRequests(_ count: Int) async {
		guard brandingRequests < count else { return }
		await withCheckedContinuation { requestWaiters.append((count, $0)) }
	}
	func waitForBrandingRequest() async { await waitForBrandingRequests(1) }
	func brandingRequestCount() -> Int { brandingRequests }
	func resolveBranding(_ branding: LauncherBranding? = nil) {
		let value =
			branding
			?? LauncherBranding(
				launcherBackgroundImage: nil, launcherBackgroundImageCRC64: nil,
				copyrightInformation: nil, privacyPolicy: nil, userAgreement: nil,
				noticePopOpen: nil, noticeContent: nil)
		let pending = brandingContinuations
		brandingContinuations.removeAll()
		for (_, continuation) in pending { continuation.resume(returning: value) }
	}

	private func cancelBrandingRequest(id: Int) {
		guard let index = brandingContinuations.firstIndex(where: { $0.id == id }) else {
			cancelledBrandingRequestIDs.insert(id)
			return
		}
		let continuation = brandingContinuations.remove(at: index).continuation
		continuation.resume(throwing: CancellationError())
	}

	private func resumeReadyWaiters() {
		let readyRequests = requestWaiters.filter { $0.0 <= brandingRequests }
		requestWaiters.removeAll { $0.0 <= brandingRequests }
		for (_, continuation) in readyRequests { continuation.resume() }
	}
}
