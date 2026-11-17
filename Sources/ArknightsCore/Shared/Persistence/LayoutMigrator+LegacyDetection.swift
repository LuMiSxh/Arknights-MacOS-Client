// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

extension LayoutMigrator {
	// MARK: - Pre-0.6 detection

	static func hasPre06Layout(
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
	static func containsLegacyGameDirectory(
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
}
