// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

extension LayoutMigrator {
	// The pre-1.0 layout kept game and environment folders under a publisher directory. Once their
	// contents moved, Finder metadata can be all that is left; a folder with real content stays.
	static func removeMetadataOnlyPublisherDirectories(
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

	static func removeMetadataOnlyTrees(
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

	static func isMetadataOnly(_ url: URL, fileManager: FileManager) throws -> Bool {
		do {
			return try metadataOnlyNode(url, fileManager: fileManager)
		} catch {
			// A symlink or an unreadable node is real content; keep the tree.
			return false
		}
	}

	static func metadataOnlyNode(_ url: URL, fileManager: FileManager) throws -> Bool {
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

	// MARK: - 0.8 development leftovers

	static func removeDevelopmentLeftovers(
		paths: AppPaths,
		selectionStore store: RuntimeSelectionStore,
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
		try store.withExclusiveAccess {
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
	}

	static func removeLegacyArtworkDirectoryIfEmpty(
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
	static func migrateLegacyArtworkCache(
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
}
