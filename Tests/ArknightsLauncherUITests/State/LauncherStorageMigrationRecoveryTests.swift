// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsLauncherUI

@MainActor
struct LauncherStorageMigrationRecoveryTests {
	private func makeConflictingModel() -> LauncherViewModel {
		makeModel(
			api: ConfigurationRefreshAPI(outcomes: [.success, .success]),
			installer: ControllableInstaller(),
			prepareStorage: { paths in
				let fileManager = FileManager.default
				try? fileManager.createDirectory(
					at: paths.applicationSupportRoot.appending(path: "Games/Arknights-Global"),
					withIntermediateDirectories: true)
				try? fileManager.createDirectory(
					at: paths.gameInstall(for: .global), withIntermediateDirectories: true)
			}
		)
	}

	@Test
	func failedMigrationReleasesTheActivityGateAndOffersRetry() async throws {
		let model = makeConflictingModel()

		#expect(await model.waitForStartup() == false)

		#expect(model.lifecycle.activity == .idle)
		let failure = try #require(model.lifecycle.state.presentation.failure)
		#expect(failure.code == .basalt)
		#expect(failure.blocksGameLaunch)
		#expect(failure.actions == [.retry, .openTroubleshooting, .reportProblem])
		#expect(model.lifecycle.state.presentation.status != .migratingStorage)
	}
}
