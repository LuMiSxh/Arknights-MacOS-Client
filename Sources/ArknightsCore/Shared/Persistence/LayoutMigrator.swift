// SPDX-License-Identifier: MPL-2.0

import Darwin
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
	private enum MoveKind {
		case game
		case prefix
		case artwork
		case playtime
	}

	private struct Move {
		let region: GameRegion?
		let kind: MoveKind
		let source: URL
		let destination: URL
	}

	private struct LayoutDocument: Codable {
		let schemaVersion: Int
	}

	private enum NodeState: Equatable {
		case absent
		case directory
		case file
	}

	package static func migrate(
		paths: AppPaths,
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
				if try preflight(move, fileManager: fileManager, log: log) {
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
			try removeDevelopmentLeftovers(paths: paths, fileManager: fileManager)
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
	package static func migrateCurrentLayout(
		paths: AppPaths,
		fileManager: FileManager = .default
	) -> LayoutMigrationResult? {
		do {
			guard try layoutIsCurrent(at: paths.layoutFile, fileManager: fileManager) else {
				return nil
			}
			try migrateLegacyArtworkCache(paths: paths, fileManager: fileManager)
			try removeMetadataOnlyPublisherDirectories(paths: paths, fileManager: fileManager)
			try ensureArtworkDirectory(paths: paths, fileManager: fileManager)
			return LayoutMigrationResult(installDirectoriesToUpdate: [:])
		} catch {
			return LayoutMigrationResult(installDirectoriesToUpdate: [:], failure: error)
		}
	}

	// MARK: - Layout marker

	private static func layoutIsCurrent(
		at url: URL,
		fileManager: FileManager
	) throws -> Bool {
		switch try nodeState(at: url) {
		case .absent:
			return false
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
			return true
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
			schemaVersion: AppConstants.Storage.layoutSchemaVersion)
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

	// MARK: - Pre-0.6 detection

	private static func hasPre06Layout(
		paths: AppPaths,
		fileManager: FileManager
	) throws -> Bool {
		let root = paths.applicationSupportRoot
		if try containsLegacyGameDirectory(
			in: root.appending(path: "Games", directoryHint: .isDirectory),
			fileManager: fileManager)
		{
			return true
		}
		return try containsLegacyGameDirectory(
			in: root.appending(path: "Wine/Prefixes", directoryHint: .isDirectory),
			fileManager: fileManager)
	}

	// Only the `Arknights-<server>` directories that the old migrator moved count. Finder leaves
	// `.DS_Store` files and empty folders behind, and those are not data.
	private static func containsLegacyGameDirectory(
		in directory: URL,
		fileManager: FileManager
	) throws -> Bool {
		guard try nodeState(at: directory) == .directory else { return false }
		let entries: [URL]
		do {
			entries = try fileManager.contentsOfDirectory(
				at: directory, includingPropertiesForKeys: nil)
		} catch {
			throw LayoutMigrationError.cannotInspect(directory, errno)
		}
		for entry in entries where entry.lastPathComponent.hasPrefix("Arknights-") {
			if try nodeState(at: entry) == .directory { return true }
		}
		return false
	}

	// The pre-1.0 layout kept game and environment folders under a publisher directory. Once their
	// contents moved, Finder metadata can be all that is left; a folder with real content stays.
	private static func removeMetadataOnlyPublisherDirectories(
		paths: AppPaths,
		fileManager: FileManager
	) throws {
		for publisher in GamePublisher.allCases {
			let url = paths.applicationSupportRoot.appending(
				path: publisher.storageDirectoryName, directoryHint: .isDirectory)
			guard try nodeState(at: url) == .directory else { continue }
			guard try isMetadataOnly(url, fileManager: fileManager) else { continue }
			try removeIfPresent(url, fileManager: fileManager)
		}
	}

	private static func removeMetadataOnlyTrees(
		paths: AppPaths,
		fileManager: FileManager
	) throws {
		for name in ["Games", "Wine"] {
			let url = paths.applicationSupportRoot.appending(
				path: name, directoryHint: .isDirectory)
			guard try nodeState(at: url) == .directory else { continue }
			guard try isMetadataOnly(url, fileManager: fileManager) else { continue }
			try removeIfPresent(url, fileManager: fileManager)
		}
	}

	private static func isMetadataOnly(_ url: URL, fileManager: FileManager) throws -> Bool {
		do {
			return try metadataOnlyNode(url, fileManager: fileManager)
		} catch {
			// A symlink or an unreadable node is real content; keep the tree.
			return false
		}
	}

	private static func metadataOnlyNode(_ url: URL, fileManager: FileManager) throws -> Bool {
		switch try nodeState(at: url) {
		case .absent:
			return true
		case .file:
			return url.lastPathComponent == ".DS_Store"
		case .directory:
			let entries = try fileManager.contentsOfDirectory(
				at: url, includingPropertiesForKeys: nil)
			for entry in entries {
				guard try metadataOnlyNode(entry, fileManager: fileManager) else { return false }
			}
			return true
		}
	}

	// MARK: - Moves

	private static func plannedMoves(
		paths: AppPaths,
		fileManager: FileManager
	) throws -> [Move] {
		let root = paths.applicationSupportRoot
		var moves: [Move] = GameRegion.allCases.map { region in
			Move(
				region: region,
				kind: .game,
				source: root.appending(
					path: "\(region.publisher.storageDirectoryName)/"
						+ legacyRegionName(region),
					directoryHint: .isDirectory),
				destination: paths.gameInstall(for: region))
		}
		for publisher in GamePublisher.allCases {
			for lane in RuntimeLane.allCases {
				moves.append(
					Move(
						region: nil,
						kind: .prefix,
						source: root.appending(
							path: "\(publisher.storageDirectoryName)/"
								+ lane.prefixDirectoryName,
							directoryHint: .isDirectory),
						destination: paths.winePrefix(for: publisher, lane: lane)))
			}
		}

		let artworkRoot = paths.artworkDirectory
		if try nodeState(at: paths.legacyCustomArtworkDirectory) == .directory {
			let entries: [URL]
			do {
				entries = try fileManager.contentsOfDirectory(
					at: paths.legacyCustomArtworkDirectory, includingPropertiesForKeys: nil)
			} catch {
				throw LayoutMigrationError.cannotInspect(
					paths.legacyCustomArtworkDirectory, errno)
			}
			for entry in entries {
				moves.append(
					Move(
						region: nil,
						kind: .artwork,
						source: entry,
						destination: artworkRoot.appending(path: entry.lastPathComponent)))
			}
		}

		moves.append(
			Move(
				region: nil,
				kind: .playtime,
				source: root.appending(path: "playtime-v1.json"),
				destination: paths.playtimeStatistics))
		return moves
	}

	private static func legacyRegionName(_ region: GameRegion) -> String {
		switch region {
		case .global: "Global"
		case .japan: "Japan"
		case .korea: "Korea"
		case .taiwan: "Taiwan"
		case .china: "China"
		case .chinaBilibili: "China-Bilibili"
		}
	}

	/// Returns false when the move must not run: the source is absent, or an artwork file already
	/// sits at the destination, which stays as it is.
	private static func preflight(
		_ move: Move,
		fileManager: FileManager,
		log: LauncherLog?
	) throws -> Bool {
		guard try nodeState(at: move.source) != .absent else { return false }
		guard try nodeState(at: move.destination) != .absent else { return true }
		// Artwork names can collide with a file the user already has in the flat layout. Keep the
		// existing file and leave the Custom copy in place instead of blocking every launch.
		guard move.kind != .artwork else {
			log?.info(
				"Layout migration kept the existing artwork at \(move.destination.path); "
					+ "the legacy copy stays at \(move.source.path)")
			return false
		}
		throw LayoutMigrationError.conflictingDirectories(move.source, move.destination)
	}

	private static func perform(
		_ move: Move,
		under root: URL,
		fileManager: FileManager
	) throws {
		try ensureParentDirectory(
			for: move.destination, under: root, fileManager: fileManager)
		do {
			try fileManager.moveItem(at: move.source, to: move.destination)
		} catch let moveError {
			do {
				// Another process may have finished the same move.
				if try nodeState(at: move.source) == .absent,
					try nodeState(at: move.destination) != .absent
				{
					return
				}
			} catch {
				throw LayoutMigrationError.moveFailed(
					move.source, move.destination,
					"\(moveError.localizedDescription); validation failed: "
						+ error.localizedDescription)
			}
			throw LayoutMigrationError.moveFailed(
				move.source, move.destination, moveError.localizedDescription)
		}
	}

	private static func preferenceUpdates(
		paths: AppPaths,
		persistedInstallDirectories: [GameRegion: URL],
		unfinishedRegions: Set<GameRegion>
	) -> [GameRegion: URL] {
		var updates: [GameRegion: URL] = [:]
		for region in GameRegion.allCases where !unfinishedRegions.contains(region) {
			let oldDefault = paths.applicationSupportRoot.appending(
				path: "\(region.publisher.storageDirectoryName)/\(legacyRegionName(region))",
				directoryHint: .isDirectory)
			guard
				let persisted = persistedInstallDirectories[region],
				persisted.standardizedFileURL.path == oldDefault.standardizedFileURL.path
			else { continue }
			updates[region] = paths.gameInstall(for: region)
		}
		return updates
	}

	// MARK: - Drive links

	private static func rewriteDriveLinks(
		paths: AppPaths,
		moves: [Move],
		fileManager: FileManager
	) throws {
		let mappings = moves.compactMap { move -> (URL, URL)? in
			guard move.region != nil else { return nil }
			return (move.source, move.destination)
		}
		let prefixes = GamePublisher.allCases.flatMap { publisher in
			RuntimeLane.allCases.map { paths.winePrefix(for: publisher, lane: $0) }
		}
		for prefix in prefixes {
			guard try nodeState(at: prefix) == .directory else { continue }
			let dosDevices = prefix.appending(path: "dosdevices", directoryHint: .isDirectory)
			guard try nodeState(at: dosDevices) == .directory else { continue }
			let entries: [URL]
			do {
				entries = try fileManager.contentsOfDirectory(
					at: dosDevices, includingPropertiesForKeys: [.isSymbolicLinkKey])
			} catch {
				throw LayoutMigrationError.cannotInspect(dosDevices, errno)
			}
			for entry in entries {
				let values: URLResourceValues
				do {
					values = try entry.resourceValues(forKeys: [.isSymbolicLinkKey])
				} catch {
					throw LayoutMigrationError.linkRewriteFailed(
						entry, error.localizedDescription)
				}
				guard values.isSymbolicLink == true else { continue }
				let target: String
				do {
					target = try fileManager.destinationOfSymbolicLink(atPath: entry.path)
				} catch {
					throw LayoutMigrationError.linkRewriteFailed(
						entry, error.localizedDescription)
				}
				guard target.hasPrefix("/") else { continue }
				let targetURL = URL(filePath: target).standardizedFileURL
				guard let remapped = remap(targetURL, mappings: mappings) else { continue }
				do {
					try fileManager.removeItem(at: entry)
					try fileManager.createSymbolicLink(
						at: entry, withDestinationURL: remapped)
				} catch {
					throw LayoutMigrationError.linkRewriteFailed(
						entry, error.localizedDescription)
				}
			}
		}
	}

	private static func remap(
		_ target: URL,
		mappings: [(old: URL, new: URL)]
	) -> URL? {
		let targetPath = target.path
		for mapping in mappings {
			let oldPath = mapping.old.standardizedFileURL.path
			if targetPath == oldPath { return mapping.new }
			if targetPath.hasPrefix(oldPath + "/") {
				return mapping.new.appending(
					path: String(targetPath.dropFirst(oldPath.count + 1)))
			}
		}
		return nil
	}

	// MARK: - 0.8 development leftovers

	private static func removeDevelopmentLeftovers(
		paths: AppPaths,
		fileManager: FileManager
	) throws {
		var leftovers = [
			paths.applicationSupportRoot.appending(path: "runtime-selection.json"),
			paths.applicationSupportRoot.appending(path: "storage-overview-cache.json"),
			paths.runtimeRoot.appending(path: ".downloads", directoryHint: .isDirectory),
			paths.runtimeRoot.appending(path: ".staging", directoryHint: .isDirectory),
			paths.legacyPresetGalleryCache,
		]
		leftovers += RuntimeLane.allCases.map {
			paths.runtimeRoot.appending(path: $0.rawValue, directoryHint: .isDirectory)
		}
		for url in leftovers {
			try removeIfPresent(url, fileManager: fileManager)
		}
		// A Custom artwork file that collided with an existing destination stays there, so the
		// folder is removed only once nothing is left in it.
		try removeLegacyArtworkDirectoryIfEmpty(paths: paths, fileManager: fileManager)

		// Removed runtime directories make the recorded versions stale. Keep the lane choice and
		// each lane entry whose version directory survived the migration.
		guard try nodeState(at: paths.runtimeSelectionFile) == .file else { return }
		let store = RuntimeSelectionStore(fileURL: paths.runtimeSelectionFile)
		var selection: RuntimeSelection
		do {
			selection = try store.load()
		} catch {
			throw LayoutMigrationError.invalidLayout(
				paths.runtimeSelectionFile, error.localizedDescription)
		}
		var survivingVersions: [RuntimeLane: String] = [:]
		for (lane, version) in selection.installedVersions {
			let directory = paths.runtimeVersionDirectory(for: lane, version: version)
			if try isExistingDirectory(directory) {
				survivingVersions[lane] = version
			}
		}
		guard survivingVersions != selection.installedVersions else { return }
		selection.installedVersions = survivingVersions
		do {
			try store.save(selection)
		} catch {
			throw LayoutMigrationError.cannotWriteLayout(
				paths.runtimeSelectionFile, error.localizedDescription)
		}
	}

	private static func removeLegacyArtworkDirectoryIfEmpty(
		paths: AppPaths,
		fileManager: FileManager
	) throws {
		let url = paths.legacyCustomArtworkDirectory
		switch try nodeState(at: url) {
		case .absent:
			return
		case .file:
			try removeIfPresent(url, fileManager: fileManager)
		case .directory:
			let entries: [URL]
			do {
				entries = try fileManager.contentsOfDirectory(
					at: url, includingPropertiesForKeys: nil)
			} catch {
				throw LayoutMigrationError.cannotInspect(url, errno)
			}
			guard entries.isEmpty else { return }
			try removeIfPresent(url, fileManager: fileManager)
		}
	}

	// Moves the retired `Artwork/Downloaded` files into `Artwork`, where `ArtworkCache` now looks.
	// A name that already exists in the new location wins and the old copy is dropped.
	private static func migrateLegacyArtworkCache(
		paths: AppPaths,
		fileManager: FileManager
	) throws {
		let source = paths.legacyArtworkDownloadCache
		// Later starts have nothing to move; one stat avoids walking the cache path components.
		guard try nodeState(at: source) != .absent else { return }
		try validatePathComponents(of: source, under: paths.cacheRoot)
		switch try nodeState(at: source) {
		case .absent:
			return
		case .file:
			try removeIfPresent(source, fileManager: fileManager)
			return
		case .directory:
			break
		}

		let destination = paths.artworkCache
		try validatePathComponents(of: destination, under: paths.cacheRoot)
		do {
			try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
		} catch {
			throw LayoutMigrationError.moveFailed(
				source, destination, error.localizedDescription)
		}
		let entries: [URL]
		do {
			entries = try fileManager.contentsOfDirectory(
				at: source, includingPropertiesForKeys: nil)
		} catch {
			throw LayoutMigrationError.cannotInspect(source, errno)
		}
		for entry in entries {
			let target = destination.appending(path: entry.lastPathComponent)
			try validatePathComponents(of: target, under: paths.cacheRoot)
			guard try nodeState(at: target) == .absent else {
				try removeIfPresent(entry, fileManager: fileManager)
				continue
			}
			do {
				try fileManager.moveItem(at: entry, to: target)
			} catch {
				throw LayoutMigrationError.moveFailed(
					entry, target, error.localizedDescription)
			}
		}
		try removeIfPresent(source, fileManager: fileManager)
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

	private static func removeIfPresent(_ url: URL, fileManager: FileManager) throws {
		guard try nodeState(at: url) != .absent else { return }
		do {
			try fileManager.removeItem(at: url)
		} catch {
			throw LayoutMigrationError.removeFailed(url, error.localizedDescription)
		}
	}

	// MARK: - Filesystem

	private static func nodeState(at url: URL) throws -> NodeState {
		guard let state = try nodeStateOrNil(at: url) else {
			throw LayoutMigrationError.unsafeNode(url)
		}
		return state
	}

	// A file or symbolic link at a version path is not an installed runtime.
	private static func isExistingDirectory(_ url: URL) throws -> Bool {
		try nodeStateOrNil(at: url) == .directory
	}

	/// `nil` for symbolic links and other nodes that are neither regular files nor directories.
	private static func nodeStateOrNil(at url: URL) throws -> NodeState? {
		var status = stat()
		let result = url.withUnsafeFileSystemRepresentation { representation -> Int32 in
			guard let representation else { return -1 }
			return lstat(representation, &status)
		}
		guard result == 0 else {
			let error = errno
			if error == ENOENT { return .absent }
			throw LayoutMigrationError.cannotInspect(url, error)
		}
		switch status.st_mode & S_IFMT {
		case S_IFDIR: return .directory
		case S_IFREG: return .file
		default: return nil
		}
	}

	private static func validatePathComponents(of url: URL, under root: URL) throws {
		let root = root.standardizedFileURL
		let target = url.standardizedFileURL
		guard target.pathComponents.starts(with: root.pathComponents) else {
			throw LayoutMigrationError.unsafeNode(target)
		}
		switch try nodeState(at: root) {
		case .absent: return
		case .directory: break
		case .file: throw LayoutMigrationError.unsafeNode(root)
		}
		let relativeComponents = Array(target.pathComponents.dropFirst(root.pathComponents.count))
		var component = root
		for (index, name) in relativeComponents.enumerated() {
			component.append(path: name)
			switch try nodeState(at: component) {
			case .absent: return
			case .directory: continue
			case .file:
				// Only the moved item itself may be a file; no parent may be one.
				guard index == relativeComponents.count - 1 else {
					throw LayoutMigrationError.unsafeNode(component)
				}
			}
		}
	}

	private static func ensureParentDirectory(
		for url: URL,
		under root: URL,
		fileManager: FileManager
	) throws {
		let parent = url.deletingLastPathComponent()
		try validatePathComponents(of: parent, under: root)
		do {
			try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
		} catch {
			throw LayoutMigrationError.moveFailed(
				url, parent, error.localizedDescription)
		}
		try validatePathComponents(of: parent, under: root)
	}
}
