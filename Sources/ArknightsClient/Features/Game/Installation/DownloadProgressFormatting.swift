// SPDX-License-Identifier: MPL-2.0

import Foundation

enum DownloadProgressFormatting {
	private static var byteCountStyle: ByteCountFormatStyle {
		ByteCountFormatStyle(
			style: .file,
			allowedUnits: .all,
			includesActualByteCount: false
		).locale(Locale(identifier: "en_US_POSIX"))
	}

	static func byteCount(_ bytes: Int64) -> String {
		max(0, bytes).formatted(byteCountStyle)
	}

	static func byteCount(_ bytes: UInt64) -> String {
		byteCount(bytes > UInt64(Int64.max) ? Int64.max : Int64(bytes))
	}

	static func byteRate(_ bytesPerSecond: Double) -> String {
		let rounded = min(Double(Int64.max), max(0, bytesPerSecond)).rounded()
		let bytes = Int64(rounded)
		return bytes.formatted(byteCountStyle) + "/s"
	}
}
