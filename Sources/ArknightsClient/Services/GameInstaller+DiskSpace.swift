// SPDX-License-Identifier: MPL-2.0

import Foundation

extension GameInstaller {
	/// Walks up to the nearest existing ancestor since `url` (e.g. a not-yet-created
	/// install directory) may not exist yet.
	static func availableCapacityBytes(at url: URL, fileManager: FileManager = .default) -> Int64? {
		var directory = url
		while !fileManager.fileExists(atPath: directory.path) {
			let parent = directory.deletingLastPathComponent()
			guard parent != directory else { return nil }
			directory = parent
		}
		guard
			let values = try? directory.resourceValues(
				forKeys: [.volumeAvailableCapacityForImportantUsageKey])
		else {
			return nil
		}
		return values.volumeAvailableCapacityForImportantUsage
	}
}
