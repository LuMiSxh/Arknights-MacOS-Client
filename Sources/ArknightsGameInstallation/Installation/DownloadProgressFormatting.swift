// SPDX-License-Identifier: MPL-2.0

import Foundation

package enum DownloadProgressFormatting {
	private static var byteCountStyle: ByteCountFormatStyle {
		ByteCountFormatStyle(
			style: .file,
			allowedUnits: .all,
			includesActualByteCount: false
		).locale(Locale(identifier: "en_US_POSIX"))
	}

	package static func byteCount(_ bytes: Int64) -> String {
		max(0, bytes).formatted(byteCountStyle)
	}

	package static func byteCount(_ bytes: UInt64) -> String {
		byteCount(bytes > UInt64(Int64.max) ? Int64.max : Int64(bytes))
	}

	package static func byteRate(_ bytesPerSecond: Double) -> String {
		let rounded = min(Double(Int64.max), max(0, bytesPerSecond)).rounded()
		let bytes = Int64(rounded)
		return bytes.formatted(byteCountStyle) + "/s"
	}

	package static func transferSummary(downloadedBytes: Int64, totalBytes: Int64) -> String {
		"\(byteCount(downloadedBytes)) of \(byteCount(totalBytes))"
	}
}

extension DownloadProgress {
	/// The "downloaded of total" text shared by the HUD and onboarding progress rows.
	package var transferSummary: String {
		DownloadProgressFormatting.transferSummary(
			downloadedBytes: downloadedBytes,
			totalBytes: totalBytes
		)
	}
}
