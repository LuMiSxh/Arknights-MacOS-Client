// SPDX-License-Identifier: MPL-2.0

import Foundation

enum RuntimeMigration: String, CaseIterable, Codable, Sendable {
	case initializeWinePrefix = "initialize-wine-prefix"
	case installDXMT = "install-dxmt"
	case configureRegistry = "configure-registry"
}

struct RuntimeMigrationState: Codable, Equatable, Sendable {
	static let currentSchemaVersion = 1

	let schemaVersion: Int
	let runtimeRevision: String
	private(set) var completed: [RuntimeMigration]

	init(
		runtimeRevision: String,
		completed: [RuntimeMigration] = []
	) {
		schemaVersion = Self.currentSchemaVersion
		self.runtimeRevision = runtimeRevision
		self.completed = completed
	}

	func contains(_ migration: RuntimeMigration) -> Bool {
		completed.contains(migration)
	}

	mutating func complete(_ migration: RuntimeMigration) {
		guard !contains(migration) else { return }
		completed.append(migration)
	}
}

struct RuntimeMigrationPlan: Sendable {
	private(set) var state: RuntimeMigrationState
	let pending: [RuntimeMigration]

	init(
		expectedRevision: String,
		installedState: RuntimeMigrationState?,
		hasSystemRegistry: Bool,
		invalidatedMigrations: Set<RuntimeMigration> = []
	) {
		let canResume =
			hasSystemRegistry
			&& installedState?.schemaVersion == RuntimeMigrationState.currentSchemaVersion
			&& installedState?.runtimeRevision == expectedRevision
		let resolvedState =
			canResume
			? installedState ?? RuntimeMigrationState(runtimeRevision: expectedRevision)
			: RuntimeMigrationState(runtimeRevision: expectedRevision)
		state = resolvedState
		let firstPendingIndex = RuntimeMigration.allCases.firstIndex {
			!resolvedState.contains($0) || invalidatedMigrations.contains($0)
		}
		pending =
			firstPendingIndex.map {
				Array(RuntimeMigration.allCases[$0...])
			} ?? []
	}

	mutating func complete(_ migration: RuntimeMigration) {
		state.complete(migration)
	}
}

struct RuntimeMigrationStore {
	static let stateFileName = ".arknights-runtime-migrations.json"
	static let legacyRevisionFileName = ".arknights-runtime-revision"
	static let legacyConfigurationFileName = ".arknights-runtime-configuration"

	private let fileManager: FileManager

	init(fileManager: FileManager = .default) {
		self.fileManager = fileManager
	}

	func load(from prefixDirectory: URL) -> RuntimeMigrationState? {
		let stateURL = prefixDirectory.appending(path: Self.stateFileName)
		guard
			let data = try? Data(contentsOf: stateURL),
			let state = try? JSONDecoder().decode(RuntimeMigrationState.self, from: data)
		else {
			return nil
		}
		return state
	}

	func loadLegacy(
		from prefixDirectory: URL,
		expectedRevision: String,
		hasSystemRegistry: Bool
	) -> RuntimeMigrationState? {
		guard hasSystemRegistry else { return nil }
		let revision = readLegacyMarker(
			Self.legacyRevisionFileName,
			from: prefixDirectory
		)
		let configuration = readLegacyMarker(
			Self.legacyConfigurationFileName,
			from: prefixDirectory
		)
		guard revision == expectedRevision || configuration == expectedRevision else {
			return nil
		}

		var completed: [RuntimeMigration] = []
		if revision == expectedRevision {
			completed.append(.initializeWinePrefix)
		}
		if configuration == expectedRevision {
			completed.append(contentsOf: [.installDXMT, .configureRegistry])
		}
		return RuntimeMigrationState(
			runtimeRevision: expectedRevision,
			completed: completed
		)
	}

	func save(_ state: RuntimeMigrationState, to prefixDirectory: URL) throws {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		var data = try encoder.encode(state)
		data.append(0x0A)
		try data.write(
			to: prefixDirectory.appending(path: Self.stateFileName),
			options: .atomic
		)
	}

	func removeLegacyMarkers(from prefixDirectory: URL) throws {
		for name in [Self.legacyRevisionFileName, Self.legacyConfigurationFileName] {
			let marker = prefixDirectory.appending(path: name)
			guard fileManager.fileExists(atPath: marker.path) else { continue }
			try fileManager.removeItem(at: marker)
		}
	}

	private func readLegacyMarker(_ name: String, from prefixDirectory: URL) -> String? {
		try? String(
			contentsOf: prefixDirectory.appending(path: name),
			encoding: .utf8
		)
	}
}
