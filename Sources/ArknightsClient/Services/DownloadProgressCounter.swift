// SPDX-License-Identifier: MPL-2.0

import Foundation

actor ProgressCounter {
	private let totalBytes: Int64
	private let totalFiles: Int
	private var downloadedBytes: Int64 = 0
	private var completedFiles = 0
	private var lastEmission = ContinuousClock.now

	init(totalBytes: Int64, totalFiles: Int) {
		self.totalBytes = totalBytes
		self.totalFiles = totalFiles
	}

	func add(bytes: Int64, file: String, force: Bool = false) -> DownloadProgress? {
		downloadedBytes += bytes
		if force {
			completedFiles += 1
		}

		let now = ContinuousClock.now
		guard force || lastEmission.duration(to: now) >= .milliseconds(100) else {
			return nil
		}
		lastEmission = now
		return DownloadProgress(
			downloadedBytes: downloadedBytes,
			totalBytes: totalBytes,
			completedFiles: completedFiles,
			totalFiles: totalFiles,
			currentFile: file
		)
	}
}
