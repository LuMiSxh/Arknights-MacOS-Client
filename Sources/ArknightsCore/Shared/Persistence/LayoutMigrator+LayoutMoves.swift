// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

extension LayoutMigrator {
	// MARK: - Moves

	static func plannedMoves(
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

	static func legacyRegionName(_ region: GameRegion) -> String {
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
	static func preflight(
		_ move: Move,
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

	static func perform(
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

	static func preferenceUpdates(
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

	static func rewriteDriveLinks(
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

	static func remap(
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
}
