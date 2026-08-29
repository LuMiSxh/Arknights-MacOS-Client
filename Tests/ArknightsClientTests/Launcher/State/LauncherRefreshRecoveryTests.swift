// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherRefreshRecoveryTests {
	@Test(arguments: GameRegion.allCases)
	func requiredConfigurationFailureRetriesTheCurrentRegion(region: GameRegion) async throws {
		let api = ConfigurationRefreshAPI(
			outcomes: region == .global ? [.failure, .success] : [.success, .failure, .success]
		)
		let model = makeModel(api: api, installer: ControllableInstaller())
		if region != .global {
			await model.waitForStartup()
			model.selectRegion(region)
		}

		#expect(await waitForCondition { model.lifecycle.failure?.code == .virga })
		let failure = try #require(model.lifecycle.failure)
		#expect(failure.context.operation == .configurationRefresh)
		#expect(failure.context.region == region.supportRegion)
		#expect(failure.blocksGameLaunch)
		#expect(
			failure.actions == [.retry, .showLogs, .openTroubleshooting, .reportProblem]
		)

		#expect(model.performRecoveryAction(.retry, failureID: failure.id) == .completed)
		#expect(model.performRecoveryAction(.retry, failureID: failure.id) == .ignored)
		#expect(await waitForCondition { model.installation.configuration != nil })
		#expect(await api.requestedRegions().last == region)
	}

	@Test
	func installedAutomaticFailureStaysInLogsButManualCheckPresentsVirga() async throws {
		let api = ConfigurationRefreshAPI(outcomes: [.success, .failure, .failure])
		let model = makeModel(api: api, installer: ControllableInstaller())
		await model.waitForStartup()
		try writeInstalledState(for: model.installation)
		model.installation.updateInstalledState()
		#expect(model.installation.isInstalled)

		await model.refreshController.startRefresh().value
		#expect(model.lifecycle.failure == nil)

		model.refreshController.checkGameUpdates()
		await model.refreshController.waitForCurrentRefresh()
		#expect(model.lifecycle.failure?.code == .virga)
		#expect(model.lifecycle.failure?.context.operation == .configurationRefresh)
		#expect(model.lifecycle.failure?.blocksGameLaunch == false)
	}
}

@MainActor
private func writeInstalledState(for installation: InstallationController) throws {
	try FileManager.default.createDirectory(
		at: installation.installDirectory,
		withIntermediateDirectories: true
	)
	try Data().write(to: installation.installDirectory.appending(path: "Arknights.exe"))
	let state = InstalledState(
		version: "1.0.0",
		basis: "test",
		source: "test",
		installedAt: .now,
		files: nil
	)
	let encoder = JSONEncoder()
	encoder.dateEncodingStrategy = .iso8601
	try encoder.encode(state).write(
		to: installation.installDirectory.appending(
			path: AppConstants.Game.installedStateFileName
		)
	)
}

private actor ConfigurationRefreshAPI: LauncherAPIProviding {
	enum Outcome: Equatable, Sendable {
		case success
		case failure
	}

	private var outcomes: [Outcome]
	private var regions: [GameRegion] = []
	private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

	init(outcomes: [Outcome]) {
		self.outcomes = outcomes
	}

	func gameConfiguration(region: GameRegion) async throws -> GameConfiguration {
		regions.append(region)
		let ready = waiters.filter { $0.0 <= regions.count }
		waiters.removeAll { $0.0 <= regions.count }
		for waiter in ready { waiter.1.resume() }
		let outcome = outcomes.isEmpty ? .success : outcomes.removeFirst()
		guard outcome == .success else {
			throw ContextualLauncherError(
				userMessage: "Configuration unavailable.",
				diagnosticDescription: "Test configuration failure."
			)
		}
		return testConfiguration
	}

	func branding(region: GameRegion) async throws -> LauncherBranding {
		LauncherBranding(
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

	func waitForRequests(_ count: Int) async {
		guard regions.count < count else { return }
		await withCheckedContinuation { waiters.append((count, $0)) }
	}

	func requestedRegions() -> [GameRegion] { regions }
}

private let testConfiguration = GameConfiguration(
	gameLowestVersion: "1.0.0",
	gameLatestVersion: "2.0.0",
	gameLatestFilePath: "game.zip",
	gameStartExeName: "Arknights",
	gameStartParams: [],
	gameUninstallScript: "uninstall.exe",
	decompressionSize: "1 GB"
)
