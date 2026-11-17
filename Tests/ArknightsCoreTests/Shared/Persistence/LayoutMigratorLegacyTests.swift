// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCore

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
		selectionStore: fixture.selectionStore,
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
		selectionStore: fixture.selectionStore,
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
