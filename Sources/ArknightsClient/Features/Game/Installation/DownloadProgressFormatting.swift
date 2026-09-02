// SPDX-License-Identifier: MPL-2.0

import Foundation

enum DownloadProgressFormatting {
	private static var byteCountStyle: ByteCountFormatStyle {
		ByteCountFormatStyle(
			style: .file,
			allowedUnits: .all,
			includesActualByteCount: false
		).locale(L10n.activeLocale ?? .current)
	}

	static func byteCount(_ bytes: Int64) -> String {
		max(0, bytes).formatted(byteCountStyle)
	}

	static func byteRate(_ bytesPerSecond: Double) -> String {
		let rounded = min(Double(Int64.max), max(0, bytesPerSecond)).rounded()
		let bytes = Int64(rounded)
		return bytes.formatted(byteCountStyle) + "/s"
	}
}
