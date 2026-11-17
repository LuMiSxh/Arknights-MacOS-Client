// SPDX-License-Identifier: MPL-2.0

import Foundation

/// The outcome of one layout migration run. A run can succeed in part: `installDirectoriesToUpdate`
/// covers every finished move, and `failure` names the step that stopped the run.
package struct LayoutMigrationResult: Sendable {
	package let installDirectoriesToUpdate: [GameRegion: URL]
	package let failure: (any Error)?
	/// The data folder still holds the pre-0.6 layout, which this version cannot migrate.
	package let requiresLegacyDataNotice: Bool
	/// A Wine process is still running, so the migration stopped before moving anything.
	package let wineIsRunning: Bool

	package init(
		installDirectoriesToUpdate: [GameRegion: URL],
		failure: (any Error)? = nil,
		requiresLegacyDataNotice: Bool = false,
		wineIsRunning: Bool = false
	) {
		self.installDirectoriesToUpdate = installDirectoriesToUpdate
		self.failure = failure
		self.requiresLegacyDataNotice = requiresLegacyDataNotice
		self.wineIsRunning = wineIsRunning
	}
}

enum LayoutMigrationError: Error, Equatable, Sendable, CustomStringConvertible {
	case unsafeNode(URL)
	case conflictingDirectories(URL, URL)
	case cannotInspect(URL, Int32)
	case moveFailed(URL, URL, String)
	case invalidLayout(URL, String)
	case unsupportedSchema(URL, Int)
	case removeFailed(URL, String)
	case linkRewriteFailed(URL, String)
	case cannotWriteLayout(URL, String)
	case cannotCreateDirectory(URL, String)

	var description: String {
		switch self {
		case .unsafeNode(let url):
			"Unsafe non-file or symbolic-link node: \(url.path)"
		case .conflictingDirectories(let old, let new):
			"Both the old and the new location exist: \(old.path) and \(new.path)"
		case .cannotInspect(let url, let error):
			"Could not inspect storage node \(url.path) (errno \(error))"
		case .moveFailed(let old, let new, let reason):
			"Could not move \(old.path) to \(new.path): \(reason)"
		case .invalidLayout(let url, let reason):
			"Could not read the layout file \(url.path): \(reason)"
		case .unsupportedSchema(let url, let version):
			"The layout file \(url.path) uses unsupported schema version \(version)"
		case .removeFailed(let url, let reason):
			"Could not delete the old storage node \(url.path): \(reason)"
		case .linkRewriteFailed(let url, let reason):
			"Could not rewrite the drive link \(url.path): \(reason)"
		case .cannotWriteLayout(let url, let reason):
			"Could not write the layout file \(url.path): \(reason)"
		case .cannotCreateDirectory(let url, let reason):
			"Could not create the directory \(url.path): \(reason)"
		}
	}
}

/// Moves the released 0.6/0.7 Application Support layout to the flat by-type layout once.
///
/// Every step is idempotent and uses same-volume renames. It never overwrites a destination, and it
/// writes `layout.json` last, so a stopped run can continue on the next start.
package enum LayoutMigrator {
	enum MoveKind {
		case game
		case prefix
		case artwork
		case playtime
	}

	struct Move {
		let region: GameRegion?
		let kind: MoveKind
		let source: URL
		let destination: URL
	}

	private struct LayoutDocument: Codable {
		let schemaVersion: Int
		// Absent from layout files written before the cleanup marker existed. `nil` means the
		// leftover cleanup has not been recorded yet, so it runs on the next start.
		let leftoversCleaned: Bool?
	}

	enum NodeState: Equatable {
		case absent
		case directory
		case file
	}

	package static func migrate(
		paths: AppPaths,
		selectionStore: RuntimeSelectionStore,
		persistedInstallDirectories: [GameRegion: URL],
		isWineRunning: @Sendable () async -> Bool = { false },
		log: LauncherLog? = nil,
		fileManager: FileManager = .default
	) async -> LayoutMigrationResult {
		if let finished = migrateCurrentLayout(paths: paths, fileManager: fileManager) {
			return finished
		}
		do {
			// Cache files keep their names, so moving them into the parent `Artwork` folder lets
			// the launcher reuse its downloaded artwork instead of downloading it again.
			try migrateLegacyArtworkCache(paths: paths, fileManager: fileManager)
			if try hasPre06Layout(paths: paths, fileManager: fileManager) {
				return LayoutMigrationResult(
					installDirectoriesToUpdate: [:], requiresLegacyDataNotice: true)
			}

			let planned = try plannedMoves(paths: paths, fileManager: fileManager)
			var moves: [Move] = []
			for move in planned {
				try validatePathComponents(of: move.source, under: paths.applicationSupportRoot)
				try validatePathComponents(
					of: move.destination, under: paths.applicationSupportRoot)
				if try preflight(move, log: log) {
					moves.append(move)
				}
			}

			// Renaming a game or environment folder under a running Wine process would corrupt it.
			if !moves.isEmpty, await isWineRunning() {
				return LayoutMigrationResult(
					installDirectoriesToUpdate: [:], wineIsRunning: true)
			}

			// The old 0.5 migrator left `Games/` and `Wine/` trees that hold only Finder metadata.
			// Remove them before the move creates the new `Games/` children.
			try removeMetadataOnlyTrees(paths: paths, fileManager: fileManager)

			var failure: (any Error)?
			var stopped = false
			var unfinishedRegions: Set<GameRegion> = []
			for move in moves {
				if stopped {
					if let region = move.region { unfinishedRegions.insert(region) }
					continue
				}
				do {
					guard try nodeState(at: move.source) != .absent else { continue }
					try perform(move, under: paths.applicationSupportRoot, fileManager: fileManager)
				} catch {
					failure = error
					stopped = true
					if let region = move.region { unfinishedRegions.insert(region) }
				}
			}

			let updates = preferenceUpdates(
				paths: paths,
				persistedInstallDirectories: persistedInstallDirectories,
				unfinishedRegions: unfinishedRegions
			)
			if let failure {
				return LayoutMigrationResult(
					installDirectoriesToUpdate: updates, failure: failure)
			}

			try rewriteDriveLinks(paths: paths, moves: moves, fileManager: fileManager)
			try removeDevelopmentLeftovers(
				paths: paths, selectionStore: selectionStore, fileManager: fileManager)
			try removeMetadataOnlyPublisherDirectories(paths: paths, fileManager: fileManager)
			try writeLayout(paths: paths, fileManager: fileManager)
			return LayoutMigrationResult(installDirectoriesToUpdate: updates)
		} catch {
			return LayoutMigrationResult(installDirectoriesToUpdate: [:], failure: error)
		}
	}

	/// The layout-current fast path for a start that has nothing to migrate.
	///
	/// It reads the marker and finishes cleanup a completed migration may have left behind. It
	/// never scans the process list and never waits, so callers on the main thread can use it
	/// before the first run-loop turn. Returns `nil` when the full migration must run.
	/// The layout-current fast path for a start that has nothing to migrate.
	///
	/// It reads the marker and runs the leftover cleanup once, then records it in the marker. It
	/// never scans the process list and never waits, so callers on the main thread can use it
	/// before the first run-loop turn. Returns `nil` when the full migration must run.
	package static func migrateCurrentLayout(
		paths: AppPaths,
		fileManager: FileManager = .default
	) -> LayoutMigrationResult? {
		do {
			guard let layout = try readLayout(at: paths.layoutFile) else { return nil }
			if layout.leftoversCleaned != true {
				try migrateLegacyArtworkCache(paths: paths, fileManager: fileManager)
				try removeMetadataOnlyPublisherDirectories(paths: paths, fileManager: fileManager)
				// Written only after both steps succeed, so a failed start runs them again.
				try writeLayout(paths: paths, fileManager: fileManager)
			}
			try ensureArtworkDirectory(paths: paths, fileManager: fileManager)
			return LayoutMigrationResult(installDirectoriesToUpdate: [:])
		} catch {
			return LayoutMigrationResult(installDirectoriesToUpdate: [:], failure: error)
		}
	}

	// MARK: - Layout marker

	/// Reads the layout marker. Returns `nil` when the data folder has none.
	private static func readLayout(at url: URL) throws -> LayoutDocument? {
		switch try nodeState(at: url) {
		case .absent:
			return nil
		case .directory:
			throw LayoutMigrationError.unsafeNode(url)
		case .file:
			let data: Data
			do {
				data = try Data(contentsOf: url)
			} catch {
				throw LayoutMigrationError.invalidLayout(url, error.localizedDescription)
			}
			let document: LayoutDocument
			do {
				document = try JSONDecoder().decode(LayoutDocument.self, from: data)
			} catch {
				throw LayoutMigrationError.invalidLayout(url, error.localizedDescription)
			}
			guard document.schemaVersion == AppConstants.Storage.layoutSchemaVersion else {
				throw LayoutMigrationError.unsupportedSchema(url, document.schemaVersion)
			}
			return document
		}
	}

	/// Writes the marker for a new data folder after the old data was deleted.
	package static func writeFreshLayout(
		paths: AppPaths,
		fileManager: FileManager = .default
	) throws {
		try writeLayout(paths: paths, fileManager: fileManager)
	}

	private static func writeLayout(paths: AppPaths, fileManager: FileManager) throws {
		let document = LayoutDocument(
			schemaVersion: AppConstants.Storage.layoutSchemaVersion, leftoversCleaned: true)
		let data: Data
		do {
			data = try JSONEncoder().encode(document)
		} catch {
			throw LayoutMigrationError.cannotWriteLayout(
				paths.layoutFile, error.localizedDescription)
		}
		try ensureArtworkDirectory(paths: paths, fileManager: fileManager)
		do {
			try fileManager.createDirectory(
				at: paths.applicationSupportRoot, withIntermediateDirectories: true)
			try data.write(to: paths.layoutFile, options: .atomic)
		} catch {
			throw LayoutMigrationError.cannotWriteLayout(
				paths.layoutFile, error.localizedDescription)
		}
	}

	// Customized artwork, icons, and the logo source live in `Artwork`, so the folder exists on
	// every start and customization only has to write its files.
	private static func ensureArtworkDirectory(
		paths: AppPaths,
		fileManager: FileManager
	) throws {
		let url = paths.artworkDirectory
		switch try nodeState(at: url) {
		case .absent:
			do {
				try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
			} catch {
				throw LayoutMigrationError.cannotCreateDirectory(url, error.localizedDescription)
			}
		case .directory:
			break
		case .file:
			throw LayoutMigrationError.unsafeNode(url)
		}
	}
}
