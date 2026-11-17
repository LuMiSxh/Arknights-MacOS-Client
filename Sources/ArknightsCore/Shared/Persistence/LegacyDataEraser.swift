// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

/// Deletes the contents of the app-owned data roots for a fresh install.
///
/// It removes children only, never the roots themselves. A symbolic link is removed as a link, so
/// a target outside the roots stays untouched. The caller removes custom install folders never.
package enum LegacyDataEraser {
	package static func erase(
		paths: AppPaths,
		fileManager: FileManager = .default
	) throws {
		try removeContents(of: paths.applicationSupportRoot, fileManager: fileManager)
		try removeContents(of: paths.cacheRoot, fileManager: fileManager)
	}

	/// Drops saved install locations that the launcher no longer has data for.
	package static func removeInstallPathKeys(userDefaults: UserDefaults) {
		for region in GameRegion.allCases {
			userDefaults.removeObject(
				forKey: LauncherPreferencesStore.Key.installPath(for: region))
		}
	}

	private static func removeContents(of root: URL, fileManager: FileManager) throws {
		guard try nodeState(at: root) == .directory else { return }
		let entries: [URL]
		do {
			entries = try fileManager.contentsOfDirectory(
				at: root, includingPropertiesForKeys: nil)
		} catch {
			throw LegacyDataEraseError.cannotEnumerate(root, error.localizedDescription)
		}
		for entry in entries {
			try removeItem(at: entry, fileManager: fileManager)
		}
	}

	private static func removeItem(at url: URL, fileManager: FileManager) throws {
		let state: NodeState
		do {
			state = try nodeState(at: url)
		} catch {
			throw LegacyDataEraseError.cannotInspect(url, error.localizedDescription)
		}
		switch state {
		case .absent:
			return
		case .directory:
			let entries: [URL]
			do {
				entries = try fileManager.contentsOfDirectory(
					at: url, includingPropertiesForKeys: nil)
			} catch {
				throw LegacyDataEraseError.cannotEnumerate(url, error.localizedDescription)
			}
			for entry in entries {
				try removeItem(at: entry, fileManager: fileManager)
			}
		case .file, .symbolicLink:
			break
		}
		do {
			try fileManager.removeItem(at: url)
		} catch  where AppPaths.isMissingPathError(error) {
			return
		} catch {
			throw LegacyDataEraseError.cannotRemove(url, error.localizedDescription)
		}
	}

	private enum NodeState: Equatable {
		case absent
		case directory
		case file
		case symbolicLink
	}

	private static func nodeState(at url: URL) throws -> NodeState {
		var status = stat()
		let result = url.withUnsafeFileSystemRepresentation { representation -> Int32 in
			guard let representation else { return -1 }
			return lstat(representation, &status)
		}
		guard result == 0 else {
			if errno == ENOENT { return .absent }
			throw LegacyDataEraseError.cannotInspect(url, "errno \(errno)")
		}
		switch status.st_mode & S_IFMT {
		case S_IFDIR: return .directory
		case S_IFREG: return .file
		case S_IFLNK: return .symbolicLink
		default: return .file
		}
	}
}

enum LegacyDataEraseError: LocalizedError, Equatable, Sendable {
	case cannotEnumerate(URL, String)
	case cannotInspect(URL, String)
	case cannotRemove(URL, String)

	var errorDescription: String? {
		switch self {
		case .cannotEnumerate(let url, let reason):
			"Could not list \(url.path): \(reason)"
		case .cannotInspect(let url, let reason):
			"Could not inspect \(url.path): \(reason)"
		case .cannotRemove(let url, let reason):
			"Could not delete \(url.path): \(reason)"
		}
	}
}
