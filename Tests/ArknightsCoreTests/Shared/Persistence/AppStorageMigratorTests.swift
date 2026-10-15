// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore

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
	let temporary = try TemporaryDirectory("AppStorageMigratorTests")
	defer { temporary.remove() }
	let root = temporary.url
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
		persistedInstallDirectories: [
			.global: legacyGame,
			.korea: paths.applicationSupportRoot.appending(path: "Games/Arknights-Korea"),
			.japan: root.appending(path: "Custom-Game"),
		],
		fileManager: fileManager
	)

	#expect(!fileManager.fileExists(atPath: legacyGame.path))
	#expect(
		fileManager.fileExists(
			atPath: paths.gameInstall(for: .global).appending(path: "marker").path))
	#expect(!fileManager.fileExists(atPath: legacyPrefix.path))
	#expect(fileManager.fileExists(atPath: paths.winePrefix.appending(path: "marker").path))
	#expect(result.installDirectoriesToUpdate[.global] == paths.gameInstall(for: .global))
	#expect(result.installDirectoriesToUpdate[.korea] == paths.gameInstall(for: .korea))
	#expect(result.installDirectoriesToUpdate[.japan] == nil)

	let raceRoot = root.appending(path: "Race", directoryHint: .isDirectory)
	let racePaths = AppPaths(
		applicationSupportDirectory: raceRoot.appending(path: "Support"),
		cachesDirectory: raceRoot.appending(path: "Caches"),
		libraryDirectory: raceRoot.appending(path: "Library")
	)
	let raceLegacy = racePaths.applicationSupportRoot.appending(path: "Games/Arknights-Global")
	try fileManager.createDirectory(at: raceLegacy, withIntermediateDirectories: true)
	let raced = AppStorageMigrator.migrate(
		paths: racePaths,
		persistedInstallDirectories: [:],
		fileManager: ConcurrentMoveFileManager()
	)
	#expect(raced.failure == nil)
	#expect(!fileManager.fileExists(atPath: raceLegacy.path))
	#expect(fileManager.fileExists(atPath: racePaths.gameInstall(for: .global).path))
}

@Test
func appStorageMigratorRejectsConflictsWithoutChangingEitherDirectory() throws {
	let temporary = try TemporaryDirectory("AppStorageMigratorConflictTests")
	defer { temporary.remove() }
	let root = temporary.url
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

	let linkRoot = root.appending(path: "Link", directoryHint: .isDirectory)
	let linkPaths = AppPaths(
		applicationSupportDirectory: linkRoot.appending(path: "Support"),
		cachesDirectory: linkRoot.appending(path: "Caches"),
		libraryDirectory: linkRoot.appending(path: "Library")
	)
	let link = linkPaths.applicationSupportRoot.appending(path: "Games/Arknights-Global")
	try fileManager.createDirectory(
		at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
	try fileManager.createSymbolicLink(at: link, withDestinationURL: root)
	let linked = AppStorageMigrator.migrate(
		paths: linkPaths, persistedInstallDirectories: [:], fileManager: fileManager)
	#expect(linked.failure is AppStorageMigrationError)
	#expect(!fileManager.fileExists(atPath: linkPaths.gameInstall(for: .global).path))
}

@Test
func appStorageMigratorReportsCompletedMovesWhenALaterMoveFailsAndResumesOnRetry() throws {
	let temporary = try TemporaryDirectory("AppStorageMigratorPartialTests")
	defer { temporary.remove() }
	let root = temporary.url
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
