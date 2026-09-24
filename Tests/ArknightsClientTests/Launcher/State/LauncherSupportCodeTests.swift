// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct LauncherSupportCodeTests {
	@Test
	func storageMigrationFailureUsesLocalFilesystemSupportCode() {
		let logURL = FileManager.default.temporaryDirectory.appending(
			path: "LauncherSupportCodeTests.\(UUID().uuidString).log"
		)
		let lifecycle = LauncherLifecycleStore(log: LauncherLog(fileURL: logURL))

		lifecycle.show(
			LauncherError.storageMigrationFailed("migration failed"),
			blocksGameLaunch: true
		)

		#expect(lifecycle.failure?.code == .basalt)
		#expect(lifecycle.failure?.actions.contains(.openTroubleshooting) == true)
		#expect(lifecycle.failure?.actions.contains(.reportProblem) == true)
		#expect(lifecycle.failure?.blocksGameLaunch == true)
	}

	@Test
	func diskCapacityInspectionFailureUsesLocalFilesystemSupportCode() {
		let url = URL(filePath: "/tmp/Arknights")

		#expect(
			InstallationController.supportCode(
				for: DiskCapacityError.noExistingAncestor(url)
			) == .basalt
		)
	}

	@Test
	func runtimeStateReadFailureUsesRuntimeSupportCode() {
		let url = URL(filePath: "/tmp/Arknights/.arknights-runtime-migrations.json")

		#expect(
			GameSessionController.supportCode(
				for: BoundedFileReadError.tooLarge(url, maximumBytes: 1)
			) == .sepia
		)
	}
}
