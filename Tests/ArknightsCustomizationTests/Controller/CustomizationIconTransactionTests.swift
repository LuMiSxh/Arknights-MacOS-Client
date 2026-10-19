// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCustomization

@MainActor
struct CustomizationIconTransactionTests {
	@Test(arguments: [(2, false, false), (3, false, false), (2, true, false), (2, false, true)])
	func failedPresetCommitRestoresEarlierFilesOrReportsRollbackFailure(
		failedStage: Int,
		failRollback: Bool,
		passive: Bool
	) async throws {
		let failedDestination = failedStage == 2 ? "game-icon" : "operator-avatar-source"
		var bundleIconApplyCount = 0
		var runningIconApplyCount = 0
		let fixture = try makeCustomizationController(
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
					throw CustomizationError.cannotSetAppIcon
				}
				throw CocoaError(.fileWriteUnknown)
			},
			setBundleIcon: { _ in
				bundleIconApplyCount += 1
				return true
			},
			setRunningIcon: { _ in runningIconApplyCount += 1 }
		)
		defer { fixture.temporary.remove() }
		let previous = try writeOperatorIconSet(fixture.paths)
		if failedStage == 2 && !failRollback && !passive {
			try FileManager.default.removeItem(at: fixture.paths.customAppIcon)
		}
		fixture.controller.setHasCustomAppIcon(true)
		fixture.controller.setHasCustomGameIcon(true)

		if passive {
			await fixture.controller.refreshOperatorPresetIconsForTheme(hue: 0.7)
		} else {
			await fixture.controller.applyPresetAvatar(
				data: try #require(solidImage(.systemGreen).tiffRepresentation)
			)
		}

		if failRollback {
			#expect(try Data(contentsOf: fixture.paths.customAppIcon) != previous.launcher)
			#expect(fixture.controller.lifecycle.state.presentation.failure != nil)
		} else if failedStage == 2 && !passive {
			#expect(!FileManager.default.fileExists(atPath: fixture.paths.customAppIcon.path))
			#expect(try Data(contentsOf: fixture.paths.customGameIcon) == previous.game)
			#expect(try Data(contentsOf: fixture.paths.operatorPresetAvatar) == previous.source)
		} else {
			#expect(try Data(contentsOf: fixture.paths.customAppIcon) == previous.launcher)
			#expect(try Data(contentsOf: fixture.paths.customGameIcon) == previous.game)
			#expect(try Data(contentsOf: fixture.paths.operatorPresetAvatar) == previous.source)
			#expect(passive || fixture.controller.lifecycle.state.presentation.failure != nil)
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
	func changedIconDestinationRejectsPreparedSnapshotBeforeCommit() async throws {
		let fixture = try makeCustomizationController()
		defer { fixture.temporary.remove() }
		let previous = try writeOperatorIconSet(fixture.paths)
		let destinations = [fixture.paths.customAppIcon, fixture.paths.customGameIcon]
		let prepared = try await CustomizationImageIO.preparePublication(
			destinations,
			operationID: UUID(),
			log: fixture.controller.log
		)
		let newerAppIcon = Data("newer app icon".utf8)
		try newerAppIcon.write(to: fixture.paths.customAppIcon, options: .atomic)
		let stages = destinations.map {
			CustomizationImageIO.stagedURL(for: $0, operationID: UUID())
		}
		try Data("replacement app icon".utf8).write(to: stages[0])
		try Data("replacement game icon".utf8).write(to: stages[1])

		#expect(throws: IconPublicationSnapshotError.self) {
			try CustomizationImageIO.publish(
				[
					(staged: stages[0], destination: destinations[0]),
					(staged: stages[1], destination: destinations[1]),
				],
				prepared: prepared,
				using: CustomizationImageIO.commit,
				log: fixture.controller.log
			)
		}
		#expect(try Data(contentsOf: fixture.paths.customAppIcon) == newerAppIcon)
		#expect(try Data(contentsOf: fixture.paths.customGameIcon) == previous.game)
		let files = try FileManager.default.contentsOfDirectory(
			atPath: fixture.paths.customAppIcon.deletingLastPathComponent().path)
		#expect(!files.contains { $0.contains(".backup.") })
	}
}

@MainActor
private func writeOperatorIconSet(
	_ paths: AppPaths
) throws -> (
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
