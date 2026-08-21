// SPDX-License-Identifier: MPL-2.0

import Foundation

/// One-time Wine prefix setup step, recorded so it isn't replayed on every launch.
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

/// Decides which migrations still need to run: a schema or runtime-revision mismatch, a
/// missing system registry, or an explicitly invalidated step all restart from that point
/// forward, rather than replaying every step unconditionally.
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

/// Reads and writes `RuntimeMigrationState` inside the Wine prefix, importing the legacy
/// single-file revision/configuration markers older builds used before this schema existed.
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

	/// Discards the recorded migration state so the next launch replays Wine
	/// initialization, DXMT installation, and every registry override from
	/// scratch. Touches only setup bookkeeping, never game files or Wine's own
	/// user directories (saves, cookies, Documents).
	func reset(prefixDirectory: URL) throws {
		let stateURL = prefixDirectory.appending(path: Self.stateFileName)
		if fileManager.fileExists(atPath: stateURL.path) {
			try fileManager.removeItem(at: stateURL)
		}
		try removeLegacyMarkers(from: prefixDirectory)
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
