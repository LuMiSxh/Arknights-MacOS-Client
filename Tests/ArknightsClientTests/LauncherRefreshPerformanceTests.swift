// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
@Test
func refreshStartsIndependentMetadataRequestsConcurrently() async {
	let api = ConcurrentRefreshAPI()
	let root = URL(filePath: NSTemporaryDirectory()).appending(
		path: "LauncherRefreshPerformanceTests.(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	let paths = AppPaths(
		applicationSupportDirectory: root.appending(path: "Support", directoryHint: .isDirectory),
		cachesDirectory: root.appending(path: "Caches", directoryHint: .isDirectory),
		libraryDirectory: root.appending(path: "Library", directoryHint: .isDirectory)
	)
	let defaults = UserDefaults(suiteName: "LauncherRefreshPerformanceTests.(UUID().uuidString)")!
	let preferences = LauncherPreferencesStore(defaults: defaults)
	preferences.setAutomaticGameUpdates(false)
	preferences.setAutomaticLauncherUpdates(false)
	preferences.setAnnouncementsEnabled(false)
	let model = LauncherViewModel(
		api: api,
		paths: paths,
		preferences: preferences,
		arguments: []
	)

	await api.waitForBothRequests()
	#expect(await api.requestedEndpoints() == [.configuration, .branding])
	await api.resolveConfiguration()
	for _ in 0..<100 where model.phase == .checking {
		await Task.yield()
	}
	#expect(model.phase == .ready)
}

private actor ConcurrentRefreshAPI: LauncherAPIProviding {
	enum Endpoint: Hashable, Sendable {
		case configuration
		case branding
	}

	private var requested: Set<Endpoint> = []
	private var requestWaiters: [CheckedContinuation<Void, Never>] = []
	private var configurationContinuation: CheckedContinuation<GameConfiguration, Never>?

	func gameConfiguration(region: GameRegion) async throws -> GameConfiguration {
		record(.configuration)
		return await withCheckedContinuation { configurationContinuation = $0 }
	}

	func branding(region: GameRegion) async throws -> LauncherBranding {
		record(.branding)
		return LauncherBranding(
			launcherBackgroundImage: nil,
			launcherBackgroundImageCRC64: nil,
			copyrightInformation: nil,
			privacyPolicy: nil,
			userAgreement: nil,
			noticePopOpen: false,
			noticeContent: nil
		)
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

	func waitForBothRequests() async {
		guard requested.count < 2 else { return }
		await withCheckedContinuation { requestWaiters.append($0) }
	}

	func requestedEndpoints() -> Set<Endpoint> { requested }

	func resolveConfiguration() {
		configurationContinuation?.resume(
			returning: GameConfiguration(
				gameLowestVersion: "1.0.0",
				gameLatestVersion: "1.0.0",
				gameLatestFilePath: "game.json",
				gameStartExeName: "Arknights",
				gameStartParams: [],
				gameUninstallScript: "uninstall.exe",
				decompressionSize: "1 GB"
			)
		)
		configurationContinuation = nil
	}

	private func record(_ endpoint: Endpoint) {
		requested.insert(endpoint)
		guard requested.count == 2 else { return }
		for waiter in requestWaiters { waiter.resume() }
		requestWaiters.removeAll()
	}
}
