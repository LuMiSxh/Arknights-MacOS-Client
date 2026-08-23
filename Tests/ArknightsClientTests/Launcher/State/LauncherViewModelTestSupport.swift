// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
func waitForDownloadToStop(_ model: LauncherViewModel) async {
	for _ in 0..<100 where model.installation.isDownloading {
		await Task.yield()
	}
	#expect(!model.installation.isDownloading)
}

@MainActor
func makeModel(
	api: some LauncherAPIProviding,
	installer: some GameInstalling,
	checkIntelTranslation: @escaping @Sendable () async -> IntelTranslationCheck = {
		IntelTranslationCheck(state: .available, diagnostics: "test")
	},
	installRosettaSystemSoftware:
		@escaping @Sendable () async throws
		-> IntelTranslationProcessResult = {
			IntelTranslationProcessResult(status: 0, output: "test")
		},
	arguments: [String] = []
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
	let defaults = UserDefaults(suiteName: "LauncherViewModelTests.\(UUID().uuidString)")!
	let preferences = LauncherPreferencesStore(defaults: defaults)
	preferences.setAutomaticGameUpdates(false)
	preferences.setAutomaticLauncherUpdates(false)
	preferences.setAnnouncementsEnabled(false)
	return LauncherViewModel(
		api: api,
		installer: installer,
		paths: paths,
		preferences: preferences,
		checkIntelTranslation: checkIntelTranslation,
		installRosettaSystemSoftware: installRosettaSystemSoftware,
		arguments: arguments
	)
}

actor TranslationCheckSequence {
	private var states: [IntelTranslationState]
	private(set) var count = 0

	init(states: [IntelTranslationState]) {
		self.states = states
	}

	func next() -> IntelTranslationCheck {
		count += 1
		let state = states.isEmpty ? .unavailable : states.removeFirst()
		return IntelTranslationCheck(state: state, diagnostics: "test-\(count)")
	}
}

actor RosettaInstallationRecorder {
	private let status: Int32
	private(set) var count = 0

	init(status: Int32) {
		self.status = status
	}

	func install() -> IntelTranslationProcessResult {
		count += 1
		return IntelTranslationProcessResult(status: status, output: "test")
	}
}

actor BlockingBrandingAPI: LauncherAPIProviding {
	private var brandingRequestCount = 0
	private var brandingRequestWaiters:
		[(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
	private var brandingResponses: [CheckedContinuation<LauncherBranding, Never>] = []

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
		brandingRequestCount += 1
		let readyWaiters = brandingRequestWaiters.filter {
			$0.count <= brandingRequestCount
		}
		brandingRequestWaiters.removeAll { $0.count <= brandingRequestCount }
		for waiter in readyWaiters {
			waiter.continuation.resume()
		}
		return await withCheckedContinuation { brandingResponses.append($0) }
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

	func waitForBrandingRequest() async {
		await waitForBrandingRequests(1)
	}

	func waitForBrandingRequests(_ count: Int) async {
		guard brandingRequestCount < count else { return }
		await withCheckedContinuation {
			brandingRequestWaiters.append((count: count, continuation: $0))
		}
	}

	func resolveBranding(_ branding: LauncherBranding? = nil) {
		let resolvedBranding =
			branding
			?? LauncherBranding(
				launcherBackgroundImage: nil,
				launcherBackgroundImageCRC64: nil,
				copyrightInformation: nil,
				privacyPolicy: nil,
				userAgreement: nil,
				noticePopOpen: nil,
				noticeContent: nil
			)
		let responses = brandingResponses
		brandingResponses.removeAll()
		for response in responses {
			response.resume(returning: resolvedBranding)
		}
	}
}

actor ControllableInstaller: GameInstalling {
	private var count = 0
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

actor CancellableBrandingAPI: LauncherAPIProviding {
	private var brandingRequests = 0
	private var cancellations = 0
	private var requestWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
	private var cancellationWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

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
		resumeReadyWaiters()
		do {
			try await Task.sleep(for: .seconds(60))
			return LauncherBranding(
				launcherBackgroundImage: nil,
				launcherBackgroundImageCRC64: nil,
				copyrightInformation: nil,
				privacyPolicy: nil,
				userAgreement: nil,
				noticePopOpen: false,
				noticeContent: nil
			)
		} catch {
			cancellations += 1
			resumeReadyWaiters()
			throw error
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

	func waitForCancellations(_ count: Int) async {
		guard cancellations < count else { return }
		await withCheckedContinuation { cancellationWaiters.append((count, $0)) }
	}

	private func resumeReadyWaiters() {
		let readyRequests = requestWaiters.filter { $0.0 <= brandingRequests }
		requestWaiters.removeAll { $0.0 <= brandingRequests }
		for (_, continuation) in readyRequests { continuation.resume() }

		let readyCancellations = cancellationWaiters.filter { $0.0 <= cancellations }
		cancellationWaiters.removeAll { $0.0 <= cancellations }
		for (_, continuation) in readyCancellations { continuation.resume() }
	}
}
