// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

struct AppStorageMigrationResult: Sendable {
	let installDirectoriesToUpdate: [GameRegion: URL]
}

enum AppStorageMigrationError: Error, Equatable, Sendable, CustomStringConvertible {
	case unsafeNode(URL)
	case conflictingDirectories(URL, URL)
	case cannotInspect(URL, Int32)
	case moveFailed(URL, URL, String)

	var description: String {
		switch self {
		case .unsafeNode(let url): "Unsafe non-directory or symbolic-link node: \(url.path)"
		case .conflictingDirectories(let old, let new):
			"Both legacy and current directories exist: \(old.path) and \(new.path)"
		case .cannotInspect(let url, let error):
			"Could not inspect storage node \(url.path) (errno \(error))"
		case .moveFailed(let old, let new, let reason):
			"Could not move \(old.path) to \(new.path): \(reason)"
		}
	}
}

enum AppStorageMigrator {
	private struct DirectoryMove {
		let region: GameRegion?
		let legacy: URL
		let current: URL
	}

	private enum NodeState: Equatable {
		case absent
		case directory
	}

	static func migrate(
		paths: AppPaths,
		persistedInstallDirectories: [GameRegion: URL],
		fileManager: FileManager = .default
	) throws -> AppStorageMigrationResult {
		let moves = directoryMoves(for: paths)
		var states: [(move: DirectoryMove, legacyExists: Bool, currentExists: Bool)] = []
		for move in moves {
			try validatePathComponents(of: move.legacy, under: paths.applicationSupportRoot)
			try validatePathComponents(of: move.current, under: paths.applicationSupportRoot)
			let legacyExists = try nodeState(at: move.legacy) == .directory
			let currentExists = try nodeState(at: move.current) == .directory
			if legacyExists, currentExists {
				throw AppStorageMigrationError.conflictingDirectories(move.legacy, move.current)
			}
			states.append((move, legacyExists, currentExists))
		}

		for state in states where state.legacyExists && !state.currentExists {
			try ensureParentDirectory(
				for: state.move.current,
				under: paths.applicationSupportRoot,
				fileManager: fileManager
			)
			do {
				try fileManager.moveItem(at: state.move.legacy, to: state.move.current)
			} catch let moveError {
				do {
					if try nodeState(at: state.move.legacy) == .absent,
						try nodeState(at: state.move.current) == .directory
					{
						continue
					}
				} catch {
					throw AppStorageMigrationError.moveFailed(
						state.move.legacy,
						state.move.current,
						"\(moveError.localizedDescription); validation failed: \(error.localizedDescription)"
					)
				}
				throw AppStorageMigrationError.moveFailed(
					state.move.legacy, state.move.current, moveError.localizedDescription)
			}
		}

		let updates = Dictionary(
			uniqueKeysWithValues: moves.compactMap { move -> (GameRegion, URL)? in
				guard
					let region = move.region,
					let persisted = persistedInstallDirectories[region],
					persisted.standardizedFileURL.path == move.legacy.standardizedFileURL.path
				else { return nil }
				return (region, move.current)
			})
		return AppStorageMigrationResult(installDirectoriesToUpdate: updates)
	}

	private static func directoryMoves(for paths: AppPaths) -> [DirectoryMove] {
		let support = paths.applicationSupportRoot
		return [
			DirectoryMove(
				region: .global,
				legacy: support.appending(path: "Games/Arknights-Global"),
				current: paths.gameInstall(for: .global)),
			DirectoryMove(
				region: .japan,
				legacy: support.appending(path: "Games/Arknights-Japan"),
				current: paths.gameInstall(for: .japan)),
			DirectoryMove(
				region: .korea,
				legacy: support.appending(path: "Games/Arknights-Korea"),
				current: paths.gameInstall(for: .korea)),
			DirectoryMove(
				region: .china,
				legacy: support.appending(path: "Games/Arknights-China"),
				current: paths.gameInstall(for: .china)),
			DirectoryMove(
				region: .chinaBilibili,
				legacy: support.appending(path: "Games/Arknights-China-Bilibili"),
				current: paths.gameInstall(for: .chinaBilibili)),
			DirectoryMove(
				region: nil,
				legacy: support.appending(path: "Wine/Prefixes/Arknights-Global"),
				current: paths.winePrefix),
			DirectoryMove(
				region: nil,
				legacy: support.appending(path: "Wine/Prefixes/Arknights-China"),
				current: paths.chinaWinePrefix),
		]
	}

	private static func nodeState(at url: URL) throws -> NodeState {
		var status = stat()
		let result = url.withUnsafeFileSystemRepresentation { representation -> Int32 in
			guard let representation else { return -1 }
			return lstat(representation, &status)
		}
		guard result == 0 else {
			let error = errno
			if error == ENOENT { return .absent }
			throw AppStorageMigrationError.cannotInspect(url, error)
		}
		guard status.st_mode & S_IFMT == S_IFDIR else {
			throw AppStorageMigrationError.unsafeNode(url)
		}
		return .directory
	}

	private static func validatePathComponents(of url: URL, under root: URL) throws {
		let root = root.standardizedFileURL
		let target = url.standardizedFileURL
		guard target.pathComponents.starts(with: root.pathComponents) else {
			throw AppStorageMigrationError.unsafeNode(target)
		}
		switch try nodeState(at: root) {
		case .absent: return
		case .directory: break
		}
		let relativeComponents = target.pathComponents.dropFirst(root.pathComponents.count)
		var component = root
		for name in relativeComponents {
			component.append(path: name)
			switch try nodeState(at: component) {
			case .absent: return
			case .directory: continue
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
		try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
		try validatePathComponents(of: parent, under: root)
	}
}
