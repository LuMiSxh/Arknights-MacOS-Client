// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Test
func newPrefixRunsEveryDeclaredMigrationInOrder() {
	let plan = RuntimeMigrationPlan(
		expectedRevision: "runtime-prefix-2",
		installedState: nil,
		hasSystemRegistry: false
	)

	#expect(plan.pending == RuntimeMigration.allCases)
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
func incompleteEarlierMigrationReplaysDependentSteps() {
	let state = RuntimeMigrationState(
		runtimeRevision: "runtime-prefix-2",
		completed: [.installDXMT, .configureRegistry]
	)
	let plan = RuntimeMigrationPlan(
		expectedRevision: "runtime-prefix-2",
		installedState: state,
		hasSystemRegistry: true
	)

	#expect(plan.pending == RuntimeMigration.allCases)
}

@Test
func changedRuntimeRevisionReplaysEveryMigration() {
	let state = RuntimeMigrationState(
		runtimeRevision: "runtime-prefix-1",
		completed: RuntimeMigration.allCases
	)
	let plan = RuntimeMigrationPlan(
		expectedRevision: "runtime-prefix-2",
		installedState: state,
		hasSystemRegistry: true
	)

	#expect(plan.pending == RuntimeMigration.allCases)
}

@Test
func missingSystemRegistryReplaysEveryMigration() {
	let state = RuntimeMigrationState(
		runtimeRevision: "runtime-prefix-2",
		completed: RuntimeMigration.allCases
	)
	let plan = RuntimeMigrationPlan(
		expectedRevision: "runtime-prefix-2",
		installedState: state,
		hasSystemRegistry: false
	)

	#expect(plan.pending == RuntimeMigration.allCases)
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

	#expect(store.load(from: prefix) == state)
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

	let imported = store.loadLegacy(
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
