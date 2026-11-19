// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Picks the recent, small, text-only files of one folder for a diagnostics archive.
///
/// The selection is an allow-list by extension. It skips links, subfolders, old files, and files
/// over the size cap, so databases, event logs, and save data never enter the archive.
package enum DiagnosticsFileSelection {
	/// The newest files in `directory` with one of `extensions`, at most `limit`, sorted by name.
	///
	/// A missing folder yields no files.
	package static func recentFiles(
		in directory: URL,
		extensions: Set<String>,
		excludingNamePrefixes: [String] = ["HGEventLog"],
		matching accepts: (String) -> Bool = { _ in true },
		newerThan cutoff: Date,
		limit: Int = AppConstants.Diagnostics.recentFileLimit,
		maximumBytes: Int = AppConstants.Diagnostics.recentFileMaximumBytes,
		fileManager: FileManager = .default
	) throws -> [URL] {
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
				!excludingNamePrefixes.contains(where: name.hasPrefix), accepts(name)
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
}
