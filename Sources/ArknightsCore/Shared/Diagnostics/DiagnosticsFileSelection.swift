// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Picks the recent, small, text-only files of one folder for a diagnostics archive.
///
/// The selection is an allow-list by extension. It skips links, subfolders, old files, and files
/// over the size cap, so databases, event logs, and save data never enter the archive.
enum DiagnosticsFileSelection {
	/// The newest files in `directory` with one of `extensions`, at most `limit`, sorted by name.
	///
	/// A missing folder yields no files. So does a folder that is a symbolic link, or that sits
	/// below a link under `root`, so the archive never follows a link out of the game folder.
	/// `root` defaults to the parent of `directory`.
	static func recentFiles(
		in directory: URL,
		below root: URL? = nil,
		extensions: Set<String>,
		excludingNamePrefixes: [String] = ["HGEventLog"],
		matching accepts: (URL) -> Bool = { _ in true },
		newerThan cutoff: Date,
		limit: Int = AppConstants.Diagnostics.recentFileLimit,
		maximumBytes: Int = AppConstants.Diagnostics.recentFileMaximumBytes,
		fileManager: FileManager = .default
	) throws -> [URL] {
		guard try isPlainFolder(directory, below: root ?? directory.deletingLastPathComponent())
		else { return [] }
		let keys: [URLResourceKey] = [
			.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey, .fileSizeKey,
		]
		let entries: [URL]
		do {
			entries = try fileManager.contentsOfDirectory(
				at: directory, includingPropertiesForKeys: keys)
		} catch  where AppPaths.isMissingPathError(error) {
			return []
		}
		var candidates: [(url: URL, modified: Date)] = []
		for entry in entries {
			let name = entry.lastPathComponent
			guard extensions.contains(entry.pathExtension.lowercased()),
				!excludingNamePrefixes.contains(where: name.hasPrefix), accepts(entry)
			else { continue }
			let values: URLResourceValues
			do {
				values = try entry.resourceValues(forKeys: Set(keys))
			} catch  where AppPaths.isMissingPathError(error) {
				continue
			}
			guard values.isRegularFile == true, values.isSymbolicLink != true,
				let modified = values.contentModificationDate, modified >= cutoff,
				(values.fileSize ?? 0) <= maximumBytes
			else { continue }
			candidates.append((entry, modified))
		}
		return candidates.sorted { $0.modified > $1.modified }.prefix(limit)
			.map(\.url).sorted { $0.lastPathComponent < $1.lastPathComponent }
	}

	/// Whether `folder` and every folder between it and `root` exist as real directories.
	static func isPlainFolder(_ folder: URL, below root: URL) throws -> Bool {
		let stop = root.standardizedFileURL.pathComponents.count
		var current = folder.standardizedFileURL
		while current.pathComponents.count > stop {
			let values: URLResourceValues
			do {
				values = try current.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
			} catch  where AppPaths.isMissingPathError(error) {
				return false
			}
			guard values.isDirectory == true, values.isSymbolicLink != true else { return false }
			current.deleteLastPathComponent()
		}
		return true
	}
}
