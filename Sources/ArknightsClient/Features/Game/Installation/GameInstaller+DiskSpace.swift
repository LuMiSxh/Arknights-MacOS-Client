// SPDX-License-Identifier: MPL-2.0

import Foundation

enum DiskCapacityError: LocalizedError, Sendable {
	case noExistingAncestor(URL)
	case resourceValuesUnavailable(URL)
	case resourceValuesReadFailed(URL, String)

	var errorDescription: String? {
		L10n.string(
			LocalizedStringResource(
				"launcher.error.diskCapacityUnavailable",
				table: "Launcher"
			)
		)
	}
}

extension GameInstaller {
	/// Walks up to the nearest existing ancestor since `url` (e.g. a not-yet-created
	/// install directory) may not exist yet.
	static func availableCapacityBytes(at url: URL, fileManager: FileManager = .default) throws
		-> Int64
	{
		var directory = url
		while !fileManager.fileExists(atPath: directory.path) {
			let parent = directory.deletingLastPathComponent()
			guard parent != directory else { throw DiskCapacityError.noExistingAncestor(url) }
			directory = parent
		}
		do {
			let values = try directory.resourceValues(
				forKeys: [.isDirectoryKey, .volumeAvailableCapacityForImportantUsageKey])
			guard values.isDirectory == true else {
				throw DiskCapacityError.resourceValuesUnavailable(directory)
			}
			guard let capacity = values.volumeAvailableCapacityForImportantUsage else {
				throw DiskCapacityError.resourceValuesUnavailable(directory)
			}
			return capacity
		} catch let error as DiskCapacityError {
			throw error
		} catch {
			throw DiskCapacityError.resourceValuesReadFailed(
				directory,
				error.localizedDescription
			)
		}
	}
}
