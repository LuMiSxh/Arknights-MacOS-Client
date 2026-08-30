// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

private let fullReplayCases: [(String, RuntimeMigrationState?, Bool)] = [
	("new prefix", nil, false),
	(
		"incomplete earlier migration",
		RuntimeMigrationState(
			runtimeRevision: "runtime-prefix-2",
			completed: [.installDXMT, .configureRegistry]
		),
		true
	),
	(
		"changed runtime revision",
		RuntimeMigrationState(
			runtimeRevision: "runtime-prefix-1",
			completed: RuntimeMigration.allCases
		),
		true
	),
	(
		"missing system registry",
		RuntimeMigrationState(
			runtimeRevision: "runtime-prefix-2",
			completed: RuntimeMigration.allCases
		),
		false
	),
]

@Test(arguments: fullReplayCases)
func invalidPrefixStateReplaysEveryMigration(
	caseName: String,
	installedState: RuntimeMigrationState?,
	hasSystemRegistry: Bool
) {
	let plan = RuntimeMigrationPlan(
		expectedRevision: "runtime-prefix-2",
		installedState: installedState,
		hasSystemRegistry: hasSystemRegistry
	)

	#expect(plan.pending == RuntimeMigration.allCases, Comment(rawValue: caseName))
}

@Test
func interruptedMigrationResumesAtTheFirstIncompleteStep() {
	let state = RuntimeMigrationState(
		runtimeRevision: "runtime-prefix-2",
		completed: [.initializeWinePrefix]
	)
	let plan = RuntimeMigrationPlan(
		expectedRevision: "runtime-prefix-2",
		installedState: state,
		hasSystemRegistry: true
	)

	#expect(plan.pending == [.installDXMT, .configureRegistry])
}

@Test
func invalidatedMigrationReplaysItselfAndFollowingSteps() {
	let state = RuntimeMigrationState(
		runtimeRevision: "runtime-prefix-2",
		completed: RuntimeMigration.allCases
	)
	let plan = RuntimeMigrationPlan(
		expectedRevision: "runtime-prefix-2",
		installedState: state,
		hasSystemRegistry: true,
		invalidatedMigrations: [.installDXMT]
	)

	#expect(plan.pending == [.installDXMT, .configureRegistry])
}

@Test
func migrationStoreRoundTripsState() throws {
	let fileManager = FileManager.default
	let prefix = fileManager.temporaryDirectory.appending(
		path: "runtime-migration-store-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	defer { try? fileManager.removeItem(at: prefix) }
	try fileManager.createDirectory(at: prefix, withIntermediateDirectories: true)
	let store = RuntimeMigrationStore(fileManager: fileManager)
	let state = RuntimeMigrationState(
		runtimeRevision: "runtime-prefix-2",
		completed: [.initializeWinePrefix, .installDXMT]
	)

	try store.save(state, to: prefix)

	#expect(try store.load(from: prefix) == state)
}

@Test
func migrationStoreSurfacesCorruptPersistedState() throws {
	let fileManager = FileManager.default
	let prefix = fileManager.temporaryDirectory.appending(
		path: "runtime-migration-corrupt-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	defer { try? fileManager.removeItem(at: prefix) }
	try fileManager.createDirectory(at: prefix, withIntermediateDirectories: true)
	try Data("not-json".utf8).write(
		to: prefix.appending(path: RuntimeMigrationStore.stateFileName)
	)

	#expect(throws: Error.self) {
		_ = try RuntimeMigrationStore(fileManager: fileManager).load(from: prefix)
	}
}

@Test
func migrationStoreResetDiscardsStateSoEverythingReplays() throws {
	let fileManager = FileManager.default
	let prefix = fileManager.temporaryDirectory.appending(
		path: "runtime-migration-reset-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	defer { try? fileManager.removeItem(at: prefix) }
	try fileManager.createDirectory(at: prefix, withIntermediateDirectories: true)
	let store = RuntimeMigrationStore(fileManager: fileManager)
	try store.save(
		RuntimeMigrationState(
			runtimeRevision: "runtime-prefix-2",
			completed: RuntimeMigration.allCases
		),
		to: prefix
	)

	try store.reset(prefixDirectory: prefix)

	#expect(try store.load(from: prefix) == nil)
}

@Test
func migrationStoreImportsAndRemovesVersionZeroOneMarkers() throws {
	let fileManager = FileManager.default
	let prefix = fileManager.temporaryDirectory.appending(
		path: "runtime-migration-legacy-\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	defer { try? fileManager.removeItem(at: prefix) }
	try fileManager.createDirectory(at: prefix, withIntermediateDirectories: true)
	let revision = "runtime-prefix-1"
	for name in [
		RuntimeMigrationStore.legacyRevisionFileName,
		RuntimeMigrationStore.legacyConfigurationFileName,
	] {
		try revision.write(
			to: prefix.appending(path: name),
			atomically: true,
			encoding: .utf8
		)
	}
	let store = RuntimeMigrationStore(fileManager: fileManager)

	let imported = try store.loadLegacy(
		from: prefix,
		expectedRevision: revision,
		hasSystemRegistry: true
	)
	try store.removeLegacyMarkers(from: prefix)

	#expect(imported?.completed == RuntimeMigration.allCases)
	#expect(
		!fileManager.fileExists(
			atPath: prefix.appending(path: RuntimeMigrationStore.legacyRevisionFileName).path
		)
	)
	#expect(
		!fileManager.fileExists(
			atPath: prefix.appending(
				path: RuntimeMigrationStore.legacyConfigurationFileName
			).path
		)
	)
}
