// SPDX-License-Identifier: MPL-2.0

import Foundation

struct DownloadProgress: Sendable {
	let downloadedBytes: Int64
	let totalBytes: Int64
	let completedFiles: Int
	let totalFiles: Int
	let currentFile: String
	/// Bytes received from the network during this installation operation. Resumed and
	/// already-present bytes are deliberately excluded.
	let networkDownloadedBytes: Int64
	let transferRateBytesPerSecond: Double?
	let isTransferStalled: Bool
	/// Monotonic within one installer operation, so concurrent stream callbacks cannot move
	/// the controller back to an older snapshot.
	let sequence: UInt64

	init(
		downloadedBytes: Int64,
		totalBytes: Int64,
		completedFiles: Int,
		totalFiles: Int,
		currentFile: String,
		networkDownloadedBytes: Int64 = 0,
		transferRateBytesPerSecond: Double? = nil,
		isTransferStalled: Bool = false,
		sequence: UInt64 = 0
	) {
		self.downloadedBytes = downloadedBytes
		self.totalBytes = totalBytes
		self.completedFiles = completedFiles
		self.totalFiles = totalFiles
		self.currentFile = currentFile
		self.networkDownloadedBytes = networkDownloadedBytes
		self.transferRateBytesPerSecond = transferRateBytesPerSecond
		self.isTransferStalled = isTransferStalled
		self.sequence = sequence
	}

	var fraction: Double {
		guard totalBytes > 0 else { return 0 }
		return min(1, Double(downloadedBytes) / Double(totalBytes))
	}
}

struct InstallResult: Sendable {
	let downloadedFiles: Int
	let downloadedBytes: Int64
	let installDirectory: URL
}
