// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

private let migrationPlanCases:
	[(String, RuntimeMigrationState?, Bool, Set<RuntimeMigration>, [RuntimeMigration])] = [
		("new prefix", nil, false, [], RuntimeMigration.allCases),
		(
			"incomplete earlier migration",
			RuntimeMigrationState(
				runtimeRevision: "runtime-prefix-2",
				completed: [.installDXMT, .configureRegistry]
			),
			true,
			[],
			RuntimeMigration.allCases
		),
		(
			"changed runtime revision",
			RuntimeMigrationState(
				runtimeRevision: "runtime-prefix-1",
				completed: RuntimeMigration.allCases
			),
			true,
			[],
			RuntimeMigration.allCases
		),
		(
			"missing system registry",
			RuntimeMigrationState(
				runtimeRevision: "runtime-prefix-2",
				completed: RuntimeMigration.allCases
			),
			false,
			[],
			RuntimeMigration.allCases
		),
		(
			"interrupted migration resumes at its first incomplete step",
			RuntimeMigrationState(
				runtimeRevision: "runtime-prefix-2",
				completed: [.initializeWinePrefix]
			),
			true,
			[],
			[.installDXMT, .configureRegistry, .shareRuntimeLibraries, .removeLegacy32BitLibraries]
		),
		(
			"prefix migrated before library sharing existed replays only that step",
			RuntimeMigrationState(
				runtimeRevision: "runtime-prefix-2",
				completed: [.initializeWinePrefix, .installDXMT, .configureRegistry]
			),
			true,
			[],
			[.shareRuntimeLibraries, .removeLegacy32BitLibraries]
		),
		(
			"prefix migrated before legacy cleanup existed replays only the cleanup",
			RuntimeMigrationState(
				runtimeRevision: "runtime-prefix-2",
				completed: [
					.initializeWinePrefix, .installDXMT, .configureRegistry, .shareRuntimeLibraries,
				]
			),
			true,
			[],
			[.removeLegacy32BitLibraries]
		),
		(
			"invalidated migration replays itself and following steps",
			RuntimeMigrationState(
				runtimeRevision: "runtime-prefix-2",
				completed: RuntimeMigration.allCases
			),
			true,
			[.installDXMT],
			[.installDXMT, .configureRegistry, .shareRuntimeLibraries, .removeLegacy32BitLibraries]
		),
	]

@Test(arguments: migrationPlanCases)
func migrationPlanSelectsThePendingSteps(
	caseName: String,
	installedState: RuntimeMigrationState?,
	hasSystemRegistry: Bool,
	invalidatedMigrations: Set<RuntimeMigration>,
	expectedPending: [RuntimeMigration]
) {
	let plan = RuntimeMigrationPlan(
		expectedRevision: "runtime-prefix-2",
		installedState: installedState,
		hasSystemRegistry: hasSystemRegistry,
		invalidatedMigrations: invalidatedMigrations
	)

	#expect(plan.pending == expectedPending, Comment(rawValue: caseName))
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

	#expect(
		imported?.completed == [.initializeWinePrefix, .installDXMT, .configureRegistry]
	)
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

@Test
func migrationStateWrittenBeforeLibrarySharingDecodesAndRunsOnlyThatStep() throws {
	let json = """
		{"schemaVersion":1,"runtimeRevision":"runtime-prefix-2",
		"completed":["initialize-wine-prefix","install-dxmt","configure-registry"]}
		"""

	let state = try JSONDecoder().decode(RuntimeMigrationState.self, from: Data(json.utf8))
	let plan = RuntimeMigrationPlan(
		expectedRevision: "runtime-prefix-2",
		installedState: state,
		hasSystemRegistry: true
	)

	#expect(plan.pending == [.shareRuntimeLibraries, .removeLegacy32BitLibraries])
}

@Test
func migrationStateWrittenBeforeLegacyCleanupDecodesAndRunsOnlyThatStep() throws {
	let json = """
		{"schemaVersion":1,"runtimeRevision":"runtime-prefix-2",
		"completed":["initialize-wine-prefix","install-dxmt","configure-registry","share-runtime-libraries"]}
		"""

	let state = try JSONDecoder().decode(RuntimeMigrationState.self, from: Data(json.utf8))
	let plan = RuntimeMigrationPlan(
		expectedRevision: "runtime-prefix-2",
		installedState: state,
		hasSystemRegistry: true
	)

	#expect(plan.pending == [.removeLegacy32BitLibraries])
}
