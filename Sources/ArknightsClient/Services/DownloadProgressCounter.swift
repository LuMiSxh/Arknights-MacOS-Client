// SPDX-License-Identifier: MPL-2.0

import Foundation

actor ProgressCounter {
	private let totalBytes: Int64
	private let totalFiles: Int
	private var downloadedBytes: Int64
	private var completedFiles = 0
	// Chunk callbacks can fire far faster than SwiftUI needs to redraw a progress bar;
	// throttling emissions to 10/s keeps updates smooth without flooding the UI.
	private var lastEmission = ContinuousClock.now

	init(
		totalBytes: Int64,
		totalFiles: Int,
		downloadedBytes: Int64 = 0,
		completedFiles: Int = 0
	) {
		self.totalBytes = totalBytes
		self.totalFiles = totalFiles
		self.downloadedBytes = downloadedBytes
		self.completedFiles = completedFiles
	}

	func current(file: String) -> DownloadProgress {
		progress(file: file)
	}

	func remove(bytes: Int64, file: String) -> DownloadProgress {
		downloadedBytes = max(0, downloadedBytes - bytes)
		lastEmission = .now
		return progress(file: file)
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
		return progress(file: file)
	}

	private func progress(file: String) -> DownloadProgress {
		DownloadProgress(
			downloadedBytes: downloadedBytes,
			totalBytes: totalBytes,
			completedFiles: completedFiles,
			totalFiles: totalFiles,
			currentFile: file
		)
	}
}
