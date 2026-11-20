// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsCore

@Test
func runtimeVersionEntriesSurviveOnlyWhileTheirDirectoriesExist() async throws {
	let fixture = try MigrationFixture("LayoutMigratorRuntimeVersionsTests")
	defer { fixture.temporary.remove() }
	try fixture.makeDirectory(
		fixture.paths.runtimeVersionDirectory(for: .x86, version: "0.8.0"))
	let store = fixture.selectionStore
	try store.save(
		RuntimeSelection(
			override: .x86,
			installedVersions: [.x86: "0.8.0", .arm: "0.8.0"]))

	let result = await LayoutMigrator.migrate(
		paths: fixture.paths,
		selectionStore: fixture.selectionStore,
		persistedInstallDirectories: [:]
	)

	#expect(result.failure == nil, "\(String(describing: result.failure))")
	let selection = try store.load()
	#expect(selection.override == .x86)
	#expect(selection.installedVersions == [.x86: "0.8.0"])
}

@Test
func aCurrentLayoutRemovesOnlyMetadataLeftoversAndKeepsArtwork() async throws {
	let fixture = try MigrationFixture("LayoutMigratorCurrentLayoutTests")
	defer { fixture.temporary.remove() }
	try fixture.write(
		"{\"schemaVersion\": \(AppConstants.Storage.layoutSchemaVersion)}",
		to: fixture.paths.layoutFile)
	let yostar = fixture.support.appending(path: "Yostar", directoryHint: .isDirectory)
	try fixture.write("", to: yostar.appending(path: ".DS_Store"))
	try fixture.makeDirectory(yostar.appending(path: "Global", directoryHint: .isDirectory))
	let gryphline = fixture.support.appending(path: "Gryphline", directoryHint: .isDirectory)
	try fixture.makeDirectory(gryphline)
	let hypergryph = fixture.support.appending(path: "Hypergryph", directoryHint: .isDirectory)
	try fixture.write("keep", to: hypergryph.appending(path: "data/keep"))

	let result = await LayoutMigrator.migrate(
		paths: fixture.paths,
		selectionStore: fixture.selectionStore,
		persistedInstallDirectories: [:],
		isWineRunning: {
			Issue.record("A current layout must not scan for a running Wine process")
			return true
		}
	)

	#expect(result.failure == nil, "\(String(describing: result.failure))")
	#expect(!fixture.exists(yostar))
	#expect(!fixture.exists(gryphline))
	#expect(fixture.exists(hypergryph.appending(path: "data/keep")))
	#expect(FileManager.default.fileExists(atPath: fixture.paths.artworkDirectory.path))

	let covered = LayoutMigrator.migrateCurrentLayout(paths: fixture.paths)
	#expect(covered?.failure == nil, "\(String(describing: covered?.failure))")
}

@Test
func aLeftoverCleanupRunsOnceAndTheLayoutRecordsIt() async throws {
	let fixture = try MigrationFixture("LayoutMigratorOneShotTests")
	defer { fixture.temporary.remove() }
	// A layout file from before the cleanup marker existed has only the schema version.
	try fixture.write(
		"{\"schemaVersion\": \(AppConstants.Storage.layoutSchemaVersion)}",
		to: fixture.paths.layoutFile)
	let yostar = fixture.support.appending(path: "Yostar", directoryHint: .isDirectory)
	try fixture.write("", to: yostar.appending(path: ".DS_Store"))

	let first = await LayoutMigrator.migrate(
		paths: fixture.paths,
		selectionStore: fixture.selectionStore,
		persistedInstallDirectories: [:]
	)

	#expect(first.failure == nil, "\(String(describing: first.failure))")
	#expect(!fixture.exists(yostar))
	#expect(try layoutLeftoversCleaned(fixture.paths.layoutFile) == true)

	// The cleanup is recorded, so a publisher folder that appears later survives the next start.
	try fixture.write("", to: yostar.appending(path: ".DS_Store"))
	let second = await LayoutMigrator.migrate(
		paths: fixture.paths,
		selectionStore: fixture.selectionStore,
		persistedInstallDirectories: [:]
	)

	#expect(second.failure == nil, "\(String(describing: second.failure))")
	#expect(fixture.exists(yostar.appending(path: ".DS_Store")))
}
