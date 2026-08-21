// SPDX-License-Identifier: MPL-2.0

import Foundation

/// The starting point `ProgressCounter` accumulates onto: for an install resumed from a
/// partial state, already-complete files count immediately instead of waiting for a full
/// re-scan, so the progress bar doesn't jump backward when Repair or Resume restarts.
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
			// A ".part" file larger than the manifest expects is stale from a previous
			// manifest revision; GameInstaller.download discards and restarts it, so it
			// must not inflate the starting progress baseline.
			return total + (size <= item.byteCount ? size : 0)
		}
	}
}
