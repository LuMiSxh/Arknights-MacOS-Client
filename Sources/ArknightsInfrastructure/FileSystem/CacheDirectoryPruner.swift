// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Keeps a cache directory under a byte limit by deleting least recently modified files first.
package enum CacheDirectoryPruner {
	/// A file the prune could not remove. The prune keeps going and returns every failure.
	package struct Failure {
		package let url: URL
		package let error: any Error
	}

	/// Counts the regular files matching `pathExtensions` (all files when nil), then deletes the
	/// oldest until `total + incomingBytes` fits `maximumBytes`. `preserving` is never counted or
	/// deleted. Symbolic links are removed, subdirectories and other nodes stay untouched, and a
	/// file that cannot be removed is returned in the result while the prune continues.
	@discardableResult
	package static func enforceLimit(
		at directory: URL,
		maximumBytes: Int64,
		incomingBytes: Int64 = 0,
		preserving target: URL? = nil,
		pathExtensions: Set<String>? = nil,
		fileManager: FileManager = .default
	) throws -> [Failure] {
		let keys: Set<URLResourceKey> = [
			.fileSizeKey, .contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey,
		]
		let urls = try fileManager.contentsOfDirectory(
			at: directory,
			includingPropertiesForKeys: Array(keys),
			options: [.skipsHiddenFiles]
		)
		var entries: [(url: URL, size: Int64, date: Date)] = []
		var failures: [Failure] = []
		var total: Int64 = 0
		for url in urls where url != target {
			if let pathExtensions, !pathExtensions.contains(url.pathExtension) { continue }
			let values = try url.resourceValues(forKeys: keys)
			if values.isSymbolicLink == true {
				remove(url, fileManager: fileManager, failures: &failures)
				continue
			}
			guard values.isRegularFile == true else { continue }
			let size = Int64(values.fileSize ?? 0)
			total += size
			entries.append((url, size, values.contentModificationDate ?? .distantPast))
		}

		let targetTotal = maximumBytes - incomingBytes
		for entry in entries.sorted(by: { $0.date < $1.date }) where total > targetTotal {
			do {
				try fileManager.removeItem(at: entry.url)
				total -= entry.size
			} catch {
				failures.append(Failure(url: entry.url, error: error))
			}
		}
		return failures
	}

	private static func remove(
		_ url: URL,
		fileManager: FileManager,
		failures: inout [Failure]
	) {
		do {
			try fileManager.removeItem(at: url)
		} catch {
			failures.append(Failure(url: url, error: error))
		}
	}
}
