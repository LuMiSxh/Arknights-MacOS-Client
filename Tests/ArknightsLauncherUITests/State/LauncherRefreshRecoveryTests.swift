// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsCustomization
import Foundation
import Testing

@testable import ArknightsGameInstallation
@testable import ArknightsLauncherUI

@MainActor
struct LauncherRefreshRecoveryTests {
	@Test(arguments: GameRegion.yostarCases)
	func requiredConfigurationFailureRetriesTheCurrentRegion(region: GameRegion) async throws {
		let api = ConfigurationRefreshAPI(
			outcomes: region == .global ? [.failure, .success] : [.success, .failure, .success]
		)
		let model = makeModel(api: api, installer: ControllableInstaller())
		#expect(await model.waitForStartup())
		if region != .global {
			model.actions.selectRegion(region)
		}

		await model.refreshController.waitForCurrentRefresh()
		#expect(model.lifecycle.state.presentation.failure?.code == .virga)
		let failure = try #require(model.lifecycle.state.presentation.failure)
		#expect(failure.context.operation == .configurationRefresh)
		#expect(failure.context.region == region.supportRegion)
		#expect(failure.blocksGameLaunch)
		#expect(
			failure.actions == [.retry, .openTroubleshooting, .reportProblem]
		)

		#expect(model.performRecoveryAction(.retry, failureID: failure.id) == .completed)
		#expect(model.performRecoveryAction(.retry, failureID: failure.id) == .ignored)
		await model.refreshController.waitForCurrentRefresh()
		#expect(model.installation.configuration != nil)
		#expect(await api.requestedRegions().last == region)
	}
}

actor ConfigurationRefreshAPI: LauncherAPIProviding {
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
