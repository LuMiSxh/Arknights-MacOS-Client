// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

extension LayoutMigrator {
	static func removeIfPresent(_ url: URL, fileManager: FileManager) throws {
		guard try nodeState(at: url) != .absent else { return }
		do {
			try fileManager.removeItem(at: url)
		} catch {
			throw LayoutMigrationError.removeFailed(url, error.localizedDescription)
		}
	}

	// MARK: - Filesystem

	static func nodeState(at url: URL) throws -> NodeState {
		guard let state = try nodeStateOrNil(at: url) else {
			throw LayoutMigrationError.unsafeNode(url)
		}
		return state
	}

	// A file or symbolic link at a version path is not an installed runtime.
	static func isExistingDirectory(_ url: URL) throws -> Bool {
		try nodeStateOrNil(at: url) == .directory
	}

	/// `nil` for symbolic links and other nodes that are neither regular files nor directories.
	static func nodeStateOrNil(at url: URL) throws -> NodeState? {
		var status = stat()
		let result = url.withUnsafeFileSystemRepresentation { representation -> Int32 in
			guard let representation else { return -1 }
			return lstat(representation, &status)
		}
		guard result == 0 else {
			let error = errno
			if error == ENOENT { return .absent }
			throw LayoutMigrationError.cannotInspect(url, reason: "errno \(error)")
		}
		switch status.st_mode & S_IFMT {
		case S_IFDIR: return .directory
		case S_IFREG: return .file
		default: return nil
		}
	}

	// `FileManager` wraps the POSIX failure in a Cocoa error; report the code it carries.
	static func inspectionReason(for error: any Error) -> String {
		let nsError = error as NSError
		if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
			return "errno \(underlying.code)"
		}
		return nsError.localizedDescription
	}

	static func validatePathComponents(of url: URL, under root: URL) throws {
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

	static func ensureParentDirectory(
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
