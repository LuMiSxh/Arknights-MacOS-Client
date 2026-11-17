// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCore

private final class FailingMoveFileManager: FileManager {
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

private struct MigrationFixture {
	let temporary: TemporaryDirectory
	let paths: AppPaths

	init(_ label: String) throws {
		temporary = try TemporaryDirectory(label)
		paths = AppPaths(
			applicationSupportDirectory: temporary.url.appending(
				path: "Support", directoryHint: .isDirectory),
			cachesDirectory: temporary.url.appending(
				path: "Caches", directoryHint: .isDirectory),
			libraryDirectory: temporary.url.appending(
				path: "Library", directoryHint: .isDirectory),
			runtimeSelection: RuntimeSelection(selected: .x86)
		)
	}

	var support: URL { paths.applicationSupportRoot }

	func legacyGame(_ region: GameRegion) -> URL {
		support.appending(path: legacyGamePath(region), directoryHint: .isDirectory)
	}

	func legacyPrefix(_ publisher: GamePublisher, lane: RuntimeLane) -> URL {
		support.appending(
			path: "\(publisher.storageDirectoryName)/\(lane.prefixDirectoryName)",
			directoryHint: .isDirectory)
	}

	@discardableResult
	func makeDirectory(_ url: URL) throws -> URL {
		try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
		return url
	}

	func write(_ text: String, to url: URL) throws {
		try FileManager.default.createDirectory(
			at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
		try Data(text.utf8).write(to: url)
	}

	func exists(_ url: URL) -> Bool {
		FileManager.default.fileExists(atPath: url.path)
	}
}

private func legacyGamePath(_ region: GameRegion) -> String {
	let name =
		switch region {
		case .global: "Global"
		case .japan: "Japan"
		case .korea: "Korea"
		case .taiwan: "Taiwan"
		case .china: "China"
		case .chinaBilibili: "China-Bilibili"
		}
	return "\(region.publisher.storageDirectoryName)/\(name)"
}

private func layoutSchema(_ url: URL) throws -> Int? {
	guard FileManager.default.fileExists(atPath: url.path) else { return nil }
	struct Document: Decodable { let schemaVersion: Int }
	return try JSONDecoder().decode(Document.self, from: Data(contentsOf: url)).schemaVersion
}

@Test
func a07LayoutMigratesToTheFlatLayoutAndTheMarkerComesLast() async throws {
	let fixture = try MigrationFixture("LayoutMigrator07Tests")
	defer { fixture.temporary.remove() }
	let fileManager = FileManager.default
	try fixture.write("game", to: fixture.legacyGame(.global).appending(path: "marker"))
	let prefix = try fixture.makeDirectory(fixture.legacyPrefix(.yostar, lane: .x86))
	try fixture.write("prefix", to: prefix.appending(path: "marker"))
	try fixture.write("art", to: fixture.support.appending(path: "Artwork/Custom/artwork"))
	try fixture.write("{}", to: fixture.support.appending(path: "playtime-v1.json"))

	let leftovers = [
		fixture.support.appending(path: "runtime-selection.json"),
		fixture.support.appending(path: "storage-overview-cache.json"),
		fixture.paths.runtimeRoot.appending(path: "x86/marker"),
		fixture.paths.runtimeRoot.appending(path: ".downloads/archive"),
		fixture.paths.runtimeRoot.appending(path: ".staging/tree"),
		fixture.paths.cacheRoot.appending(path: "PresetGallery/image"),
	]
	for url in leftovers {
		try fixture.write("old", to: url)
	}
	let legacyArtwork = fixture.paths.legacyArtworkDownloadCache.appending(path: "image")
	try fixture.write("old", to: legacyArtwork)
	let legacyDuplicate = fixture.paths.legacyArtworkDownloadCache.appending(path: "existing")
	try fixture.write("stale", to: legacyDuplicate)
	let currentDuplicate = fixture.paths.artworkCache.appending(path: "existing")
	try fixture.write("current", to: currentDuplicate)

	let result = await LayoutMigrator.migrate(
		paths: fixture.paths,
		persistedInstallDirectories: [.global: fixture.legacyGame(.global)],
		fileManager: fileManager
	)

	#expect(
		result.failure == nil,
		"\(String(describing: result.failure))")
	#expect(!result.requiresLegacyDataNotice)
	#expect(result.installDirectoriesToUpdate[.global] == fixture.paths.gameInstall(for: .global))
	#expect(fixture.exists(fixture.paths.gameInstall(for: .global).appending(path: "marker")))
	#expect(!fixture.exists(fixture.legacyGame(.global)))
	#expect(fixture.exists(fixture.paths.winePrefix(for: .yostar, lane: .x86)))
	#expect(!fixture.exists(prefix))
	#expect(fixture.exists(fixture.paths.customArtwork))
	#expect(!fixture.exists(fixture.paths.legacyCustomArtworkDirectory))
	#expect(fixture.exists(fixture.paths.playtimeStatistics))
	#expect(fixture.exists(fixture.paths.artworkCache.appending(path: "image")))
	#expect(!fixture.exists(legacyArtwork))
	#expect(!fixture.exists(fixture.paths.legacyArtworkDownloadCache))
	#expect(try String(contentsOf: currentDuplicate, encoding: .utf8) == "current")
	#expect(try layoutSchema(fixture.paths.layoutFile) == AppConstants.Storage.layoutSchemaVersion)
	for url in leftovers {
		#expect(!fixture.exists(url))
	}
}

@Test
func aStoppedMigrationResumesWithoutLosingData() async throws {
	let fixture = try MigrationFixture("LayoutMigratorResumeTests")
	defer { fixture.temporary.remove() }
	for region in [GameRegion.global, .japan] {
		try fixture.write("game", to: fixture.legacyGame(region).appending(path: "marker"))
	}
	let prefix = try fixture.makeDirectory(fixture.legacyPrefix(.yostar, lane: .arm))
	try fixture.write("prefix", to: prefix.appending(path: "marker"))

	let fileManager = FailingMoveFileManager(failingMove: 2)
	let first = await LayoutMigrator.migrate(
		paths: fixture.paths,
		persistedInstallDirectories: [
			.global: fixture.legacyGame(.global),
			.japan: fixture.legacyGame(.japan),
		],
		fileManager: fileManager
	)

	#expect(first.failure is LayoutMigrationError)
	#expect(first.installDirectoriesToUpdate[.global] == fixture.paths.gameInstall(for: .global))
	#expect(first.installDirectoriesToUpdate[.japan] == nil)
	#expect(try layoutSchema(fixture.paths.layoutFile) == nil)
	#expect(fixture.exists(fixture.legacyGame(.japan).appending(path: "marker")))

	fileManager.recover()
	let second = await LayoutMigrator.migrate(
		paths: fixture.paths,
		persistedInstallDirectories: [
			.global: fixture.paths.gameInstall(for: .global),
			.japan: fixture.legacyGame(.japan),
		],
		fileManager: fileManager
	)

	#expect(second.failure == nil)
	#expect(fixture.exists(fixture.paths.gameInstall(for: .global).appending(path: "marker")))
	#expect(fixture.exists(fixture.paths.gameInstall(for: .japan).appending(path: "marker")))
	#expect(fixture.exists(fixture.paths.winePrefix(for: .yostar, lane: .arm)))
	#expect(try layoutSchema(fixture.paths.layoutFile) == AppConstants.Storage.layoutSchemaVersion)
}

@Test
func aDestinationConflictFailsWithoutOverwriting() async throws {
	let fixture = try MigrationFixture("LayoutMigratorConflictTests")
	defer { fixture.temporary.remove() }
	try fixture.write("old", to: fixture.legacyGame(.global).appending(path: "marker"))
	try fixture.write("new", to: fixture.paths.gameInstall(for: .global).appending(path: "marker"))

	let result = await LayoutMigrator.migrate(
		paths: fixture.paths,
		persistedInstallDirectories: [.global: fixture.legacyGame(.global)]
	)

	#expect(result.failure is LayoutMigrationError)
	#expect(result.installDirectoriesToUpdate.isEmpty)
	#expect(
		try String(
			contentsOf: fixture.paths.gameInstall(for: .global).appending(path: "marker"),
			encoding: .utf8) == "new")
	#expect(fixture.exists(fixture.legacyGame(.global)))
	#expect(try layoutSchema(fixture.paths.layoutFile) == nil)
}

@Test
func aCustomInstallPathStaysAndADefaultPathIsRewritten() async throws {
	let fixture = try MigrationFixture("LayoutMigratorPreferencesTests")
	defer { fixture.temporary.remove() }
	try fixture.write("game", to: fixture.legacyGame(.global).appending(path: "marker"))
	let custom = fixture.temporary.url.appending(
		path: "Custom-Game", directoryHint: .isDirectory)

	let result = await LayoutMigrator.migrate(
		paths: fixture.paths,
		persistedInstallDirectories: [
			.global: fixture.legacyGame(.global),
			.japan: custom,
		]
	)

	#expect(result.failure == nil)
	#expect(result.installDirectoriesToUpdate[.global] == fixture.paths.gameInstall(for: .global))
	#expect(result.installDirectoriesToUpdate[.japan] == nil)
}

@Test
func absoluteDosdevicesLinksFollowMovedDirectories() async throws {
	let fixture = try MigrationFixture("LayoutMigratorDriveTests")
	defer { fixture.temporary.remove() }
	let oldGame = try fixture.makeDirectory(fixture.legacyGame(.global))
	let oldPrefix = try fixture.makeDirectory(fixture.legacyPrefix(.yostar, lane: .x86))
	let dosDevices = try fixture.makeDirectory(oldPrefix.appending(path: "dosdevices"))
	let logs = fixture.temporary.url.appending(path: "Logs", directoryHint: .isDirectory)
	let gameDrive = dosDevices.appending(path: "g:")
	let logDrive = dosDevices.appending(path: "l:")
	try FileManager.default.createSymbolicLink(at: gameDrive, withDestinationURL: oldGame)
	try FileManager.default.createSymbolicLink(at: logDrive, withDestinationURL: logs)

	let result = await LayoutMigrator.migrate(
		paths: fixture.paths,
		persistedInstallDirectories: [.global: oldGame]
	)

	#expect(result.failure == nil)
	let newPrefix = fixture.paths.winePrefix(for: .yostar, lane: .x86)
	let newGameDrive = newPrefix.appending(path: "dosdevices/g:")
	let newLogDrive = newPrefix.appending(path: "dosdevices/l:")
	#expect(
		try FileManager.default.destinationOfSymbolicLink(atPath: newGameDrive.path)
			== fixture.paths.gameInstall(for: .global).path)
	#expect(
		try FileManager.default.destinationOfSymbolicLink(atPath: newLogDrive.path)
			== logs.path)
}

@Test(arguments: [false, true])
func metadataOnlyLeftoversMigrateButLegacyGameDirectoriesShowTheNotice(
	hasLegacyData: Bool
) async throws {
	let fixture = try MigrationFixture("LayoutMigratorMetadataTests")
	defer { fixture.temporary.remove() }
	try fixture.write("", to: fixture.support.appending(path: "Games/.DS_Store"))
	try fixture.makeDirectory(
		fixture.support.appending(path: "Games/Empty", directoryHint: .isDirectory))
	try fixture.write("", to: fixture.support.appending(path: "Wine/.DS_Store"))
	try fixture.write("", to: fixture.support.appending(path: "Wine/Prefixes/.DS_Store"))
	if hasLegacyData {
		try fixture.write(
			"game", to: fixture.support.appending(path: "Games/Arknights-Global/marker"))
	} else {
		try fixture.write("game", to: fixture.legacyGame(.global).appending(path: "marker"))
	}

	let result = await LayoutMigrator.migrate(
		paths: fixture.paths,
		persistedInstallDirectories: [.global: fixture.legacyGame(.global)]
	)

	if hasLegacyData {
		#expect(result.requiresLegacyDataNotice)
		#expect(result.failure == nil)
		#expect(fixture.exists(fixture.support.appending(path: "Games/Arknights-Global")))
		#expect(try layoutSchema(fixture.paths.layoutFile) == nil)
	} else {
		#expect(!result.requiresLegacyDataNotice)
		#expect(result.failure == nil)
		#expect(
			fixture.exists(
				fixture.paths.gameInstall(for: .global).appending(path: "marker")))
		#expect(!fixture.exists(fixture.support.appending(path: "Games/.DS_Store")))
		#expect(!fixture.exists(fixture.support.appending(path: "Wine")))
		#expect(
			try layoutSchema(fixture.paths.layoutFile)
				== AppConstants.Storage.layoutSchemaVersion)
	}
}

@Test
func pre05DataShowsTheNoticeAndMovesNothing() async throws {
	let fixture = try MigrationFixture("LayoutMigratorLegacyNoticeTests")
	defer { fixture.temporary.remove() }
	let oldGame = try fixture.makeDirectory(
		fixture.support.appending(path: "Games/Arknights-Global"))
	let oldPrefix = try fixture.makeDirectory(
		fixture.support.appending(path: "Wine/Prefixes/Arknights-Global"))

	let result = await LayoutMigrator.migrate(
		paths: fixture.paths,
		persistedInstallDirectories: [:]
	)

	#expect(result.requiresLegacyDataNotice)
	#expect(result.failure == nil)
	#expect(result.installDirectoriesToUpdate.isEmpty)
	#expect(fixture.exists(oldGame))
	#expect(fixture.exists(oldPrefix))
	#expect(!fixture.exists(fixture.paths.gameInstall(for: .global)))
	#expect(!fixture.exists(fixture.paths.winePrefix(for: .yostar, lane: .x86)))
	#expect(try layoutSchema(fixture.paths.layoutFile) == nil)
}

@Test
func anArtworkCollisionKeepsBothCopiesAndTheMigrationFinishes() async throws {
	let fixture = try MigrationFixture("LayoutMigratorArtworkConflictTests")
	defer { fixture.temporary.remove() }
	let collided = fixture.support.appending(path: "Artwork/Custom/artwork")
	try fixture.write("old", to: collided)
	try fixture.write("new", to: fixture.paths.customArtwork)
	try fixture.write("copy", to: fixture.support.appending(path: "Artwork/Custom/second"))

	let result = await LayoutMigrator.migrate(
		paths: fixture.paths,
		persistedInstallDirectories: [:]
	)

	#expect(result.failure == nil, "\(String(describing: result.failure))")
	#expect(try String(contentsOf: fixture.paths.customArtwork, encoding: .utf8) == "new")
	#expect(fixture.exists(collided))
	#expect(fixture.exists(fixture.support.appending(path: "Artwork/second")))
	#expect(try layoutSchema(fixture.paths.layoutFile) == AppConstants.Storage.layoutSchemaVersion)
}

@Test
func aPrefixConflictStaysFatal() async throws {
	let fixture = try MigrationFixture("LayoutMigratorPrefixConflictTests")
	defer { fixture.temporary.remove() }
	let legacy = try fixture.makeDirectory(fixture.legacyPrefix(.yostar, lane: .x86))
	try fixture.write("old", to: legacy.appending(path: "marker"))
	let destination = fixture.paths.winePrefix(for: .yostar, lane: .x86)
	try fixture.write("new", to: destination.appending(path: "marker"))

	let result = await LayoutMigrator.migrate(
		paths: fixture.paths,
		persistedInstallDirectories: [:]
	)

	#expect(result.failure is LayoutMigrationError)
	#expect(fixture.exists(legacy.appending(path: "marker")))
	#expect(
		try String(contentsOf: destination.appending(path: "marker"), encoding: .utf8) == "new")
	#expect(try layoutSchema(fixture.paths.layoutFile) == nil)
}

@Test
func runtimeVersionEntriesSurviveOnlyWhileTheirDirectoriesExist() async throws {
	let fixture = try MigrationFixture("LayoutMigratorRuntimeVersionsTests")
	defer { fixture.temporary.remove() }
	try fixture.makeDirectory(
		fixture.paths.runtimeVersionDirectory(for: .x86, version: "0.8.0"))
	let store = RuntimeSelectionStore(fileURL: fixture.paths.runtimeSelectionFile)
	try store.save(
		RuntimeSelection(
			selected: .x86,
			installedVersions: [.x86: "0.8.0", .arm: "0.8.0"]))

	let result = await LayoutMigrator.migrate(
		paths: fixture.paths,
		persistedInstallDirectories: [:]
	)

	#expect(result.failure == nil, "\(String(describing: result.failure))")
	let selection = try store.load()
	#expect(selection.selected == .x86)
	#expect(selection.installedVersions == [.x86: "0.8.0"])
}

@Test
func aFreshInstallWritesTheLayoutMarker() async throws {
	let fixture = try MigrationFixture("LayoutMigratorFreshTests")
	defer { fixture.temporary.remove() }

	let result = await LayoutMigrator.migrate(
		paths: fixture.paths,
		persistedInstallDirectories: [:]
	)

	#expect(result.failure == nil)
	#expect(!result.requiresLegacyDataNotice)
	#expect(try layoutSchema(fixture.paths.layoutFile) == AppConstants.Storage.layoutSchemaVersion)
}

@Test
func aRunningWineProcessStopsTheMigrationBeforeAnyMove() async throws {
	let fixture = try MigrationFixture("LayoutMigratorWineRunningTests")
	defer { fixture.temporary.remove() }
	try fixture.write("game", to: fixture.legacyGame(.global).appending(path: "marker"))

	let result = await LayoutMigrator.migrate(
		paths: fixture.paths,
		persistedInstallDirectories: [.global: fixture.legacyGame(.global)],
		isWineRunning: { true }
	)

	#expect(result.wineIsRunning)
	#expect(result.failure == nil)
	#expect(result.installDirectoriesToUpdate.isEmpty)
	#expect(fixture.exists(fixture.legacyGame(.global).appending(path: "marker")))
	#expect(!fixture.exists(fixture.paths.gameInstall(for: .global)))
	#expect(try layoutSchema(fixture.paths.layoutFile) == nil)
}

@Test
func theWineCheckIsSkippedWhenNothingWouldMove() async throws {
	let fixture = try MigrationFixture("LayoutMigratorNoMoveWineCheckTests")
	defer { fixture.temporary.remove() }

	let result = await LayoutMigrator.migrate(
		paths: fixture.paths,
		persistedInstallDirectories: [:],
		isWineRunning: { true }
	)

	#expect(!result.wineIsRunning)
	#expect(result.failure == nil)
	#expect(try layoutSchema(fixture.paths.layoutFile) == AppConstants.Storage.layoutSchemaVersion)
}
