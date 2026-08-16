// SPDX-License-Identifier: MPL-2.0

import Foundation

struct DownloadProgressBaseline: Sendable {
	let totalBytes: Int64
	let totalFiles: Int
	let downloadedBytes: Int64
	let completedFiles: Int

	init(
		manifestFiles: [ManifestFile],
		pendingFiles: [ManifestFile],
		isIncompleteInstallation: Bool,
		partialSize: (ManifestFile) throws -> Int64
	) rethrows {
		let pendingPaths = Set(pendingFiles.map(\.path))
		let reusedFiles =
			isIncompleteInstallation
			? manifestFiles.filter { !pendingPaths.contains($0.path) }
			: []
		let measuredFiles = isIncompleteInstallation ? manifestFiles : pendingFiles
		totalBytes = measuredFiles.reduce(Int64(0)) { $0 + $1.byteCount }
		totalFiles = measuredFiles.count
		completedFiles = reusedFiles.count
		downloadedBytes = try pendingFiles.reduce(
			reusedFiles.reduce(Int64(0)) { $0 + $1.byteCount }
		) { total, item in
			let size = try partialSize(item)
			return total + (size <= item.byteCount ? size : 0)
		}
	}
}
