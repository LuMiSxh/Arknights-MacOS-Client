// SPDX-License-Identifier: MPL-2.0

import Foundation

struct DownloadProgress: Sendable {
	let downloadedBytes: Int64
	let totalBytes: Int64
	let completedFiles: Int
	let totalFiles: Int
	let currentFile: String

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
