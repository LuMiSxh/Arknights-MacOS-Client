// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

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

	let result = try AppStorageMigrator.migrate(
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
	let result = try AppStorageMigrator.migrate(
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

	#expect(throws: AppStorageMigrationError.self) {
		try AppStorageMigrator.migrate(
			paths: paths, persistedInstallDirectories: [:], fileManager: fileManager)
	}
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

	#expect(throws: AppStorageMigrationError.self) {
		try AppStorageMigrator.migrate(
			paths: paths,
			persistedInstallDirectories: [:],
			fileManager: fileManager
		)
	}
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

	_ = try AppStorageMigrator.migrate(
		paths: paths,
		persistedInstallDirectories: [:],
		fileManager: ConcurrentMoveFileManager()
	)

	#expect(!FileManager.default.fileExists(atPath: legacy.path))
	#expect(FileManager.default.fileExists(atPath: paths.gameInstall(for: .global).path))
}
