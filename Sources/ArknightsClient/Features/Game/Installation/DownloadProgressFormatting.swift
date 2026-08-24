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

	static func duration(_ duration: Duration) -> String {
		let components = duration.components
		let totalSeconds = max(
			0,
			Double(components.seconds)
				+ Double(components.attoseconds) / 1_000_000_000_000_000_000
		)
		let threshold = durationInSeconds(AppConstants.Network.transferRateEtaMinuteSecondThreshold)
		let quantum = durationInSeconds(
			totalSeconds < 60
				? AppConstants.Network.transferRateEtaSubminuteQuantum
				: AppConstants.Network.transferRateEtaMinuteSecondQuantum
		)
		var style = Duration.UnitsFormatStyle(
			allowedUnits: totalSeconds < threshold
				? [.hours, .minutes, .seconds] : [.hours, .minutes],
			width: .abbreviated,
			maximumUnitCount: 2
		)
		style.locale = L10n.activeLocale ?? .current
		if totalSeconds >= threshold {
			let roundedMinutes = max(1, Int((totalSeconds / 60).rounded()))
			return Duration.seconds(roundedMinutes * 60).formatted(style)
		}
		let roundedSeconds = max(0, Int((totalSeconds / quantum).rounded()) * Int(quantum))
		return Duration.seconds(roundedSeconds).formatted(style)
	}

	private static func durationInSeconds(_ duration: Duration) -> Double {
		let components = duration.components
		return Double(components.seconds) + Double(components.attoseconds)
			/ 1_000_000_000_000_000_000
	}
}
