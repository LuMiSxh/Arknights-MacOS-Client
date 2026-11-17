// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
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
					at: paths.applicationSupportRoot.appending(path: "Yostar/Global"),
					withIntermediateDirectories: true)
				try? fileManager.createDirectory(
					at: paths.gameInstall(for: .global), withIntermediateDirectories: true)
			}
		)
	}

	private func makePre05Model() -> LauncherViewModel {
		makeModel(
			api: ConfigurationRefreshAPI(outcomes: [.success, .success]),
			installer: ControllableInstaller(),
			prepareStorage: { paths in
				try? FileManager.default.createDirectory(
					at: paths.applicationSupportRoot.appending(path: "Games/Arknights-Global"),
					withIntermediateDirectories: true)
			}
		)
	}

	@Test
	func failedMigrationReleasesTheActivityGateAndOffersRetry() async throws {
		let model = makeConflictingModel()

		#expect(await model.waitForStartup() == false)

		#expect(model.lifecycle.activity == .idle)
		let failure = try #require(model.lifecycle.state.presentation.failure)
		#expect(failure.code == .dataMigrationFailed)
		#expect(failure.blocksGameLaunch)
		#expect(failure.actions == [.retry, .openTroubleshooting, .reportProblem])
		#expect(model.lifecycle.state.presentation.status != .migratingStorage)
	}

	@Test
	func pre05DataShowsABlockingNoticeAndStopsStartup() async throws {
		let model = makePre05Model()

		#expect(await model.waitForStartup() == false)

		#expect(model.lifecycle.activity == .idle)
		let failure = try #require(model.lifecycle.state.presentation.failure)
		#expect(failure.title == "Data from an old launcher version")
		#expect(failure.message.contains("older than 0.6"))
		#expect(failure.actions == [.deleteDataFolder, .quit])
		#expect(!failure.showsDismissAction)
		#expect(failure.blocksGameLaunch)
		#expect(
			!FileManager.default.fileExists(
				atPath: model.paths.gameInstall(for: .global).path))
	}

	@Test
	func quitAndDeleteRouteThroughTheNoticeActions() async throws {
		let model = makePre05Model()
		#expect(await model.waitForStartup() == false)
		let failure = try #require(model.lifecycle.state.presentation.failure)
		var quitRequests = 0
		model.requestApplicationQuit = { quitRequests += 1 }

		#expect(
			model.performRecoveryAction(.deleteDataFolder, failureID: failure.id)
				== .deleteDataFolderConfirmationRequired)
		#expect(model.performRecoveryAction(.quit, failureID: failure.id) == .completed)
		#expect(quitRequests == 1)

		model.lifecycle.restoreFailure(
			LauncherFailurePresentation(
				id: failure.id,
				title: failure.title,
				message: "Deleting…",
				code: nil,
				context: failure.context,
				actions: failure.actions,
				blocksGameLaunch: true,
				showsDismissAction: false,
				isBusy: true
			))
		#expect(model.performRecoveryAction(.quit, failureID: failure.id) == .ignored)
		#expect(quitRequests == 1)
	}
}
