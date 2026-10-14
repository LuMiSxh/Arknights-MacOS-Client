// SPDX-License-Identifier: MPL-2.0

import Foundation

package struct DownloadProgress: Equatable, Sendable {
	package let downloadedBytes: Int64
	package let totalBytes: Int64
	let completedFiles: Int
	let totalFiles: Int
	let currentFile: String
	/// Bytes received from the network during this installation operation. Resumed and
	/// already-present bytes are deliberately excluded.
	let networkDownloadedBytes: Int64
	package let transferRateBytesPerSecond: Double?
	package let isTransferStalled: Bool
	/// True while existing files are hashed before any download starts. Byte and file counts
	/// then describe the verification pass instead of the transfer.
	package let isVerifying: Bool
	/// Monotonic within one installer operation, so concurrent stream callbacks cannot move
	/// the controller back to an older snapshot.
	let sequence: UInt64

	package init(
		downloadedBytes: Int64,
		totalBytes: Int64,
		completedFiles: Int,
		totalFiles: Int,
		currentFile: String,
		networkDownloadedBytes: Int64 = 0,
		transferRateBytesPerSecond: Double? = nil,
		isTransferStalled: Bool = false,
		isVerifying: Bool = false,
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
		self.isVerifying = isVerifying
		self.sequence = sequence
	}

	package var fraction: Double {
		guard totalBytes > 0 else { return 0 }
		return min(1, Double(downloadedBytes) / Double(totalBytes))
	}
}

package struct InstallResult: Sendable {
	let downloadedFiles: Int
	package let downloadedBytes: Int64
	let installDirectory: URL
}
