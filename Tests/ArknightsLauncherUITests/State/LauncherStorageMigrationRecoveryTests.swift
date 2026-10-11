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

	@Test
	func retryRunsStartupAgainOnceAfterTheUserFixesTheFolders() async throws {
		let model = makeConflictingModel()
		#expect(await model.waitForStartup() == false)
		let failure = try #require(model.lifecycle.state.presentation.failure)

		#expect(model.performRecoveryAction(.retry, failureID: failure.id) == .completed)
		#expect(model.performRecoveryAction(.retry, failureID: failure.id) == .ignored)
		#expect(await model.waitForStartup() == false)
		let second = try #require(model.lifecycle.state.presentation.failure)
		#expect(second.id != failure.id)

		try FileManager.default.removeItem(
			at: model.paths.applicationSupportRoot.appending(path: "Games/Arknights-Global"))
		#expect(model.performRecoveryAction(.retry, failureID: second.id) == .completed)
		#expect(await model.waitForStartup())

		#expect(model.lifecycle.state.presentation.failure == nil)
		#expect(model.lifecycle.activity == .idle)
		#expect(model.installation.configuration != nil)
	}

	@Test
	func retryIsRefusedWhileAnotherActivityOwnsTheLauncher() async throws {
		let model = makeConflictingModel()
		#expect(await model.waitForStartup() == false)
		let failure = try #require(model.lifecycle.state.presentation.failure)

		model.lifecycle.simulateActivity(.maintaining(.clearingCache))

		#expect(model.performRecoveryAction(.retry, failureID: failure.id) == .ignored)
		#expect(model.lifecycle.state.presentation.failure?.id == failure.id)
	}
}
