// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct CustomizationIconTransactionTests {
	@Test(arguments: [(2, false), (3, false), (2, true)])
	func failedPresetCommitRestoresEarlierFilesOrReportsRollbackFailure(
		failedStage: Int,
		failRollback: Bool
	) async throws {
		let failedDestination = failedStage == 2 ? "game-icon" : "operator-avatar-source"
		var bundleIconApplyCount = 0
		var runningIconApplyCount = 0
		let fixture = makeCustomizationController(
			iconCommitter: { staged, destination in
				let target = failRollback ? "game-icon" : failedDestination
				guard destination.lastPathComponent == target else {
					try CustomizationImageIO.commit(staged, to: destination)
					return
				}
				if failRollback {
					let siblings = try FileManager.default.contentsOfDirectory(
						at: staged.deletingLastPathComponent(), includingPropertiesForKeys: nil)
					for backup in siblings
					where backup.lastPathComponent.hasPrefix("app-icon.backup.") {
						try FileManager.default.removeItem(at: backup)
					}
					throw LauncherError.cannotSetAppIcon
				}
				throw CocoaError(.fileWriteUnknown)
			},
			setBundleIcon: { _ in
				bundleIconApplyCount += 1
				return true
			},
			setRunningIcon: { _ in runningIconApplyCount += 1 }
		)
		let previous = try writeOperatorIconSet(fixture.paths)
		if failedStage == 2 && !failRollback {
			try FileManager.default.removeItem(at: fixture.paths.customAppIcon)
		}
		fixture.controller.setHasCustomAppIcon(true)
		fixture.controller.setHasCustomGameIcon(true)

		await fixture.controller.applyPresetAvatar(
			data: try #require(solidImage(.systemGreen).tiffRepresentation)
		)

		if failRollback {
			#expect(try Data(contentsOf: fixture.paths.customAppIcon) != previous.launcher)
			#expect(
				fixture.controller.lifecycle.failureMessage?.contains("could not be fully restored")
					== true
			)
			await fixture.controller.log.flush()
			let log = try String(contentsOf: fixture.paths.launcherLogFile, encoding: .utf8)
			#expect(log.contains("Icon publication failed:"))
			#expect(log.contains("macOS refused to update the app icon."))
			#expect(log.contains("Rollback failures:"))
		} else if failedStage == 2 {
			#expect(!FileManager.default.fileExists(atPath: fixture.paths.customAppIcon.path))
			#expect(try Data(contentsOf: fixture.paths.customGameIcon) == previous.game)
			#expect(try Data(contentsOf: fixture.paths.operatorPresetAvatar) == previous.source)
		} else {
			#expect(try Data(contentsOf: fixture.paths.customAppIcon) == previous.launcher)
			#expect(try Data(contentsOf: fixture.paths.customGameIcon) == previous.game)
			#expect(try Data(contentsOf: fixture.paths.operatorPresetAvatar) == previous.source)
			#expect(fixture.controller.lifecycle.failure != nil)
		}
		#expect(fixture.controller.hasCustomAppIcon)
		#expect(fixture.controller.hasCustomGameIcon)
		#expect(bundleIconApplyCount == 0)
		#expect(runningIconApplyCount == 0)
		let files = try FileManager.default.contentsOfDirectory(
			atPath: fixture.paths.customAppIcon.deletingLastPathComponent().path)
		#expect(!files.contains { $0.contains(".stage.") })
	}

	@Test
	func failedPassiveIconCommitRestoresBothPersistedIcons() async throws {
		var bundleIconApplyCount = 0
		var runningIconApplyCount = 0
		let fixture = makeCustomizationController(
			iconCommitter: { staged, destination in
				guard destination.lastPathComponent != "game-icon" else {
					throw CocoaError(.fileWriteUnknown)
				}
				try CustomizationImageIO.commit(staged, to: destination)
			},
			setBundleIcon: { _ in
				bundleIconApplyCount += 1
				return true
			},
			setRunningIcon: { _ in runningIconApplyCount += 1 }
		)
		let previous = try writeOperatorIconSet(fixture.paths)
		fixture.controller.setHasCustomAppIcon(true)
		fixture.controller.setHasCustomGameIcon(true)

		await fixture.controller.refreshOperatorPresetIconsForTheme(hue: 0.7)

		#expect(try Data(contentsOf: fixture.paths.customAppIcon) == previous.launcher)
		#expect(try Data(contentsOf: fixture.paths.customGameIcon) == previous.game)
		#expect(try Data(contentsOf: fixture.paths.operatorPresetAvatar) == previous.source)
		#expect(fixture.controller.hasCustomAppIcon)
		#expect(fixture.controller.hasCustomGameIcon)
		#expect(bundleIconApplyCount == 0)
		#expect(runningIconApplyCount == 0)
	}

	@Test
	func cancelledStaleThemeRefreshCannotTouchANewerPresetPublication() async throws {
		let stager = ControlledRequestGate<Void, (Data, URL)>()
		var runningIconApplyCount = 0
		let fixture = makeCustomizationController(
			dataStager: { try await stager.next(($0, $1)) },
			setRunningIcon: { _ in runningIconApplyCount += 1 }
		)
		_ = try writeOperatorIconSet(fixture.paths)
		let newerAvatar = try #require(solidImage(.systemGreen).tiffRepresentation)

		let staleRefresh = fixture.controller.startOperatorPresetIconRefresh(hue: 0.1)
		await stager.waitForRequestCount(1)
		try await stager.resolveStaged(0)
		await stager.waitForRequestCount(2)

		let newerPreset = Task {
			await fixture.controller.applyPresetAvatar(data: newerAvatar)
		}
		await stager.waitForRequestCount(3)
		staleRefresh.cancel()
		await staleRefresh.value

		try await stager.resolveStaged(2)
		await stager.waitForRequestCount(4)
		try await stager.resolveStaged(3)
		await stager.waitForRequestCount(5)
		try await stager.resolveStaged(4)
		await newerPreset.value

		#expect(try Data(contentsOf: fixture.paths.operatorPresetAvatar) == newerAvatar)
		#expect(NSImage(data: try Data(contentsOf: fixture.paths.customAppIcon)) != nil)
		#expect(NSImage(data: try Data(contentsOf: fixture.paths.customGameIcon)) != nil)
		#expect(fixture.controller.hasCustomAppIcon)
		#expect(fixture.controller.hasCustomGameIcon)
		#expect(runningIconApplyCount == 1)
		let files = try FileManager.default.contentsOfDirectory(
			atPath: fixture.paths.customAppIcon.deletingLastPathComponent().path)
		#expect(!files.contains { $0.contains(".stage.") })
	}

	@Test
	func presetAndThemeRefreshPublishCompleteIconSets() async throws {
		var runningIconApplyCount = 0
		let fixture = makeCustomizationController(
			setRunningIcon: { _ in runningIconApplyCount += 1 }
		)
		let previous = try writeOperatorIconSet(fixture.paths)
		let avatar = try #require(solidImage(.systemGreen).tiffRepresentation)

		await fixture.controller.applyPresetAvatar(data: avatar)
		let presetLauncher = try Data(contentsOf: fixture.paths.customAppIcon)
		let presetGame = try Data(contentsOf: fixture.paths.customGameIcon)
		#expect(presetLauncher != previous.launcher)
		#expect(presetGame != previous.game)
		#expect(NSImage(data: presetLauncher) != nil)
		#expect(NSImage(data: presetGame) != nil)
		#expect(try Data(contentsOf: fixture.paths.operatorPresetAvatar) == avatar)
		#expect(runningIconApplyCount == 1)

		await fixture.controller.refreshOperatorPresetIconsForTheme(hue: 0.7)

		#expect(NSImage(data: try Data(contentsOf: fixture.paths.customAppIcon)) != nil)
		#expect(NSImage(data: try Data(contentsOf: fixture.paths.customGameIcon)) != nil)
		#expect(try Data(contentsOf: fixture.paths.operatorPresetAvatar) == avatar)
		#expect(fixture.controller.hasCustomAppIcon)
		#expect(fixture.controller.hasCustomGameIcon)
		#expect(runningIconApplyCount == 2)
		let files = try FileManager.default.contentsOfDirectory(
			atPath: fixture.paths.customAppIcon.deletingLastPathComponent().path)
		#expect(!files.contains { $0.contains(".backup.") || $0.contains(".stage.") })
	}
}

@MainActor
private func writeOperatorIconSet(_ paths: AppPaths) throws -> (
	launcher: Data, game: Data, source: Data
) {
	let directory = paths.customAppIcon.deletingLastPathComponent()
	try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	let files = (
		launcher: Data("previous launcher icon".utf8),
		game: Data("previous game icon".utf8),
		source: try #require(solidImage(.systemOrange).tiffRepresentation)
	)
	try files.launcher.write(to: paths.customAppIcon)
	try files.game.write(to: paths.customGameIcon)
	try files.source.write(to: paths.operatorPresetAvatar)
	return files
}
