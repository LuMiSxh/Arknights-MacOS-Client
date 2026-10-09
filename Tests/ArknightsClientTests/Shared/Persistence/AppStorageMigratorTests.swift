// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

private final class FailingMoveFileManager: FileManager, @unchecked Sendable {
	private let failingMove: Int
	private var moves = 0
	private(set) var shouldFail = true

	init(failingMove: Int) {
		self.failingMove = failingMove
		super.init()
	}

	func recover() { shouldFail = false }

	override func moveItem(at source: URL, to destination: URL) throws {
		moves += 1
		if shouldFail, moves == failingMove { throw CocoaError(.fileWriteNoPermission) }
		try FileManager.default.moveItem(at: source, to: destination)
	}
}

private final class ConcurrentMoveFileManager: FileManager {
	override func moveItem(at source: URL, to destination: URL) throws {
		try FileManager.default.moveItem(at: source, to: destination)
		throw CocoaError(.fileNoSuchFile)
	}
}

@Test
func appStorageMigratorMovesLegacyDirectoriesAndUpdatesExactInstallPreferences() throws {
	let root = FileManager.default.temporaryDirectory
		.appending(
			path: "AppStorageMigratorTests.\(UUID().uuidString)", directoryHint: .isDirectory)
	defer { try? FileManager.default.removeItem(at: root) }
	let paths = AppPaths(
		applicationSupportDirectory: root.appending(path: "Support"),
		cachesDirectory: root.appending(path: "Caches"),
		libraryDirectory: root.appending(path: "Library")
	)
	let fileManager = FileManager.default
	let legacyGame = paths.applicationSupportRoot.appending(path: "Games/Arknights-Global")
	let legacyPrefix = paths.applicationSupportRoot.appending(
		path: "Wine/Prefixes/Arknights-Global")
	try fileManager.createDirectory(at: legacyGame, withIntermediateDirectories: true)
	try fileManager.createDirectory(at: legacyPrefix, withIntermediateDirectories: true)
	try Data("game".utf8).write(to: legacyGame.appending(path: "marker"))
	try Data("prefix".utf8).write(to: legacyPrefix.appending(path: "marker"))

	let result = AppStorageMigrator.migrate(
		paths: paths,
		persistedInstallDirectories: [.global: legacyGame],
		fileManager: fileManager
	)

	#expect(!fileManager.fileExists(atPath: legacyGame.path))
	#expect(
		fileManager.fileExists(
			atPath: paths.gameInstall(for: .global).appending(path: "marker").path))
	#expect(!fileManager.fileExists(atPath: legacyPrefix.path))
	#expect(fileManager.fileExists(atPath: paths.winePrefix.appending(path: "marker").path))
	#expect(result.installDirectoriesToUpdate[.global] == paths.gameInstall(for: .global))
}

@Test
func appStorageMigratorUpdatesAbsentExactDefaultsButPreservesCustomPaths() throws {
	let root = FileManager.default.temporaryDirectory
		.appending(
			path: "AppStorageMigratorAbsentTests.\(UUID().uuidString)", directoryHint: .isDirectory)
	defer { try? FileManager.default.removeItem(at: root) }
	let paths = AppPaths(
		applicationSupportDirectory: root.appending(path: "Support"),
		cachesDirectory: root.appending(path: "Caches"),
		libraryDirectory: root.appending(path: "Library")
	)
	let legacy = paths.applicationSupportRoot.appending(path: "Games/Arknights-Global")
	let custom = root.appending(path: "Custom-Game")
	let result = AppStorageMigrator.migrate(
		paths: paths,
		persistedInstallDirectories: [
			.global: URL(filePath: legacy.path, directoryHint: .isDirectory),
			.japan: custom,
		]
	)

	#expect(result.installDirectoriesToUpdate[.global] == paths.gameInstall(for: .global))
	#expect(result.installDirectoriesToUpdate[.japan] == nil)
}

@Test
func appStorageMigratorRejectsSymbolicLinkSources() throws {
	let root = FileManager.default.temporaryDirectory
		.appending(
			path: "AppStorageMigratorSymlinkTests.\(UUID().uuidString)", directoryHint: .isDirectory
		)
	defer { try? FileManager.default.removeItem(at: root) }
	let paths = AppPaths(
		applicationSupportDirectory: root.appending(path: "Support"),
		cachesDirectory: root.appending(path: "Caches"),
		libraryDirectory: root.appending(path: "Library")
	)
	let fileManager = FileManager.default
	let legacy = paths.applicationSupportRoot.appending(path: "Games/Arknights-Global")
	try fileManager.createDirectory(
		at: legacy.deletingLastPathComponent(), withIntermediateDirectories: true)
	try fileManager.createSymbolicLink(at: legacy, withDestinationURL: root)

	let result = AppStorageMigrator.migrate(
		paths: paths, persistedInstallDirectories: [:], fileManager: fileManager)
	#expect(result.failure is AppStorageMigrationError)
	#expect(!fileManager.fileExists(atPath: paths.gameInstall(for: .global).path))
}

@Test
func appStorageMigratorRejectsConflictsWithoutChangingEitherDirectory() throws {
	let root = FileManager.default.temporaryDirectory
		.appending(
			path: "AppStorageMigratorConflictTests.\(UUID().uuidString)",
			directoryHint: .isDirectory)
	defer { try? FileManager.default.removeItem(at: root) }
	let paths = AppPaths(
		applicationSupportDirectory: root.appending(path: "Support"),
		cachesDirectory: root.appending(path: "Caches"),
		libraryDirectory: root.appending(path: "Library")
	)
	let fileManager = FileManager.default
	let legacy = paths.applicationSupportRoot.appending(path: "Games/Arknights-Global")
	try fileManager.createDirectory(at: legacy, withIntermediateDirectories: true)
	try fileManager.createDirectory(
		at: paths.gameInstall(for: .global), withIntermediateDirectories: true)

	let result = AppStorageMigrator.migrate(
		paths: paths,
		persistedInstallDirectories: [.global: legacy],
		fileManager: fileManager
	)
	#expect(result.failure is AppStorageMigrationError)
	#expect(result.installDirectoriesToUpdate.isEmpty)
	#expect(fileManager.fileExists(atPath: legacy.path))
	#expect(fileManager.fileExists(atPath: paths.gameInstall(for: .global).path))
}

@Test
func appStorageMigratorAcceptsAMoveCompletedByAnotherProcess() throws {
	let root = FileManager.default.temporaryDirectory
		.appending(path: "AppStorageMigratorRaceTests.\(UUID().uuidString)")
	defer { try? FileManager.default.removeItem(at: root) }
	let paths = AppPaths(
		applicationSupportDirectory: root.appending(path: "Support"),
		cachesDirectory: root.appending(path: "Caches"),
		libraryDirectory: root.appending(path: "Library")
	)
	let legacy = paths.applicationSupportRoot.appending(path: "Games/Arknights-Global")
	try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)

	let result = AppStorageMigrator.migrate(
		paths: paths,
		persistedInstallDirectories: [:],
		fileManager: ConcurrentMoveFileManager()
	)

	#expect(result.failure == nil)
	#expect(!FileManager.default.fileExists(atPath: legacy.path))
	#expect(FileManager.default.fileExists(atPath: paths.gameInstall(for: .global).path))
}

@Test
func appStorageMigratorReportsCompletedMovesWhenALaterMoveFailsAndResumesOnRetry() throws {
	let root = FileManager.default.temporaryDirectory
		.appending(path: "AppStorageMigratorPartialTests.\(UUID().uuidString)")
	defer { try? FileManager.default.removeItem(at: root) }
	let paths = AppPaths(
		applicationSupportDirectory: root.appending(path: "Support"),
		cachesDirectory: root.appending(path: "Caches"),
		libraryDirectory: root.appending(path: "Library")
	)
	let legacyDirectories =
		[
			.global: paths.applicationSupportRoot.appending(path: "Games/Arknights-Global"),
			.japan: paths.applicationSupportRoot.appending(path: "Games/Arknights-Japan"),
			.korea: paths.applicationSupportRoot.appending(path: "Games/Arknights-Korea"),
			.china: paths.applicationSupportRoot.appending(path: "Games/Arknights-China"),
		] as [GameRegion: URL]
	for directory in legacyDirectories.values {
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	}
	let fileManager = FailingMoveFileManager(failingMove: 3)

	let first = AppStorageMigrator.migrate(
		paths: paths, persistedInstallDirectories: legacyDirectories, fileManager: fileManager)

	#expect(first.failure is AppStorageMigrationError)
	#expect(
		first.installDirectoriesToUpdate == [
			.global: paths.gameInstall(for: .global),
			.japan: paths.gameInstall(for: .japan),
		])
	#expect(FileManager.default.fileExists(atPath: paths.gameInstall(for: .japan).path))
	#expect(FileManager.default.fileExists(atPath: legacyDirectories[.korea]!.path))
	#expect(FileManager.default.fileExists(atPath: legacyDirectories[.china]!.path))
	#expect(!FileManager.default.fileExists(atPath: paths.gameInstall(for: .china).path))

	fileManager.recover()
	let remaining = legacyDirectories.filter { first.installDirectoriesToUpdate[$0.key] == nil }
	let second = AppStorageMigrator.migrate(
		paths: paths, persistedInstallDirectories: remaining, fileManager: fileManager)

	#expect(second.failure == nil)
	#expect(
		second.installDirectoriesToUpdate == [
			.korea: paths.gameInstall(for: .korea),
			.china: paths.gameInstall(for: .china),
		])
}
