// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

@testable import ArknightsGameInstallation

actor ConfigurationRefreshAPI: LauncherAPIProviding {
	enum Outcome: Equatable, Sendable {
		case success
		case failure
	}

	private var outcomes: [Outcome]

	init(outcomes: [Outcome]) {
		self.outcomes = outcomes
	}

	func gameConfiguration(region: GameRegion) async throws -> GameConfiguration {
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
}

private let testConfiguration = GameConfiguration(
	gameLatestVersion: "2.0.0",
	gameLatestFilePath: "game.zip",
	gameStartExeName: "Arknights",
	gameStartParams: [],
	decompressionSize: "1 GB"
)
