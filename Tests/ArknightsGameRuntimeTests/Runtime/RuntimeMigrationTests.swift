// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsGameRuntime

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

@Test(
	arguments: [
		(
			#"{"schemaVersion":1,"runtimeRevision":"runtime-prefix-2","completed":["initialize-wine-prefix","install-dxmt","configure-registry"]}"#,
			[RuntimeMigration.shareRuntimeLibraries, .removeLegacy32BitLibraries]
		),
		(
			#"{"schemaVersion":1,"runtimeRevision":"runtime-prefix-2","completed":["initialize-wine-prefix","install-dxmt","configure-registry","share-runtime-libraries"]}"#,
			[.removeLegacy32BitLibraries]
		),
	]
)
func migrationStateWrittenBeforeLibrarySharingDecodesAndRunsOnlyThatStep(
	json: String,
	expectedPending: [RuntimeMigration]
) throws {
	let state = try JSONDecoder().decode(RuntimeMigrationState.self, from: Data(json.utf8))
	let plan = RuntimeMigrationPlan(
		expectedRevision: "runtime-prefix-2",
		installedState: state,
		hasSystemRegistry: true
	)

	#expect(plan.pending == expectedPending)
}

@Test
func migrationStoreRoundTripsImportsLegacyMarkersAndSurfacesCorruptPersistedState() throws {
	let fileManager = FileManager.default
	let temporary = try TemporaryDirectory("RuntimeMigrationTests")
	defer { temporary.remove() }
	let prefix = temporary.url
	let store = RuntimeMigrationStore(fileManager: fileManager)
	let state = RuntimeMigrationState(
		runtimeRevision: "runtime-prefix-2",
		completed: [.initializeWinePrefix, .installDXMT]
	)

	try store.save(state, to: prefix)
	#expect(try store.load(from: prefix) == state)
	try store.reset(prefixDirectory: prefix)
	#expect(try store.load(from: prefix) == nil)

	let revision = "runtime-prefix-1"
	let markers = [
		RuntimeMigrationStore.legacyRevisionFileName,
		RuntimeMigrationStore.legacyConfigurationFileName,
	].map { prefix.appending(path: $0) }
	for marker in markers { try revision.write(to: marker, atomically: true, encoding: .utf8) }
	let imported = try store.loadLegacy(
		from: prefix, expectedRevision: revision, hasSystemRegistry: true)
	try store.removeLegacyMarkers(from: prefix)
	#expect(imported?.completed == [.initializeWinePrefix, .installDXMT, .configureRegistry])
	#expect(markers.allSatisfy { !fileManager.fileExists(atPath: $0.path) })

	try Data("not-json".utf8).write(to: prefix.appending(path: RuntimeMigrationStore.stateFileName))
	#expect(throws: Error.self) { _ = try store.load(from: prefix) }
}
