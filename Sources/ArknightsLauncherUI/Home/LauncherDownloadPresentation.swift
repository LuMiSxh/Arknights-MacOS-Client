// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation

/// Single source for download status copy and state, shared by the HUD, the Settings
/// operation strip, and the Installation page.
enum LauncherDownloadProgressPresentation {
	static func percentage(for progress: DownloadProgress?) -> Int? {
		guard let progress, progress.totalBytes > 0 else { return nil }
		return Int(progress.fraction * 100)
	}

	static func title(for progress: DownloadProgress?, isPaused: Bool) -> String? {
		guard let percentage = percentage(for: progress) else { return nil }
		return title(
			percentage: percentage,
			isVerifying: progress?.isVerifying == true,
			isPaused: isPaused
		)
	}

	/// Settings shows the title without the progress bar beside it, so a bare percentage
	/// gets the operation name.
	static func labeledTitle(for progress: DownloadProgress?, isPaused: Bool) -> String? {
		guard let title = title(for: progress, isPaused: isPaused) else { return nil }
		return isPaused || progress?.isVerifying == true ? title : "Downloading · \(title)"
	}

	/// The widest title for a state. The HUD reserves this width so the label does not shift.
	static func widestTitle(isVerifying: Bool, isPaused: Bool) -> String {
		title(percentage: 100, isVerifying: isVerifying, isPaused: isPaused)
	}

	private static func title(percentage: Int, isVerifying: Bool, isPaused: Bool) -> String {
		if isVerifying { return "Verifying · \(percentage)%" }
		return isPaused ? "Paused · \(percentage)%" : "\(percentage)%"
	}

	static func gameStatus(
		isDownloading: Bool,
		progress: DownloadProgress?,
		isInstalled: Bool,
		hasPartialDownload: Bool
	) -> String {
		if isDownloading {
			return labeledTitle(for: progress, isPaused: false) ?? "Preparing download"
		}
		if isInstalled { return "Installed" }
		return hasPartialDownload ? "Paused" : "Not installed"
	}

	static func fraction(
		for progress: DownloadProgress?,
		isActive: Bool,
		isPaused: Bool
	) -> Double? {
		guard isActive || isPaused, let progress, progress.totalBytes > 0 else { return nil }
		return progress.fraction
	}

	/// Whether the HUD can draw an outline in this state. It changes on state transitions only,
	/// so views outside the progress leaf may read it.
	static func supportsOutline(
		status: LauncherStatus,
		hasPartialDownload: Bool,
		hasFailure: Bool
	) -> Bool {
		guard !hasFailure else { return false }

		// Startup migration is too short for a themed outline and runs before the accent loads.
		if status == .migratingStorage { return false }
		if status.isIndeterminateWork { return true }
		switch status {
		case .verifyingInstallation, .downloading, .pausing: return true
		case .paused: return hasPartialDownload
		default: return false
		}
	}

	static func outlineFraction(
		for progress: DownloadProgress?,
		status: LauncherStatus,
		hasPartialDownload: Bool,
		hasFailure: Bool
	) -> Double? {
		guard
			supportsOutline(
				status: status,
				hasPartialDownload: hasPartialDownload,
				hasFailure: hasFailure
			)
		else { return nil }
		if status.isIndeterminateWork { return 1 }
		if status == .verifyingInstallation {
			return progress?.isVerifying == true ? knownFraction(for: progress) ?? 1 : 1
		}
		return knownFraction(for: progress)
	}

	static func showsActiveProgressEffect(
		for progress: DownloadProgress?,
		status: LauncherStatus,
		hasFailure: Bool
	) -> Bool {
		guard !hasFailure else { return false }
		if status == .migratingStorage { return false }
		if status.isIndeterminateWork || status == .verifyingInstallation { return true }
		guard status == .downloading,
			let progress,
			!progress.isTransferStalled
		else { return false }

		return progress.fraction > 0 && progress.fraction < 1
	}

	private static func knownFraction(for progress: DownloadProgress?) -> Double? {
		guard let progress, progress.totalBytes > 0 else { return nil }
		return progress.fraction
	}

	static func transferDetail(
		for progress: DownloadProgress?,
		isPaused: Bool
	) -> String? {
		guard !isPaused, let progress else { return nil }
		if let rate = progress.transferRateBytesPerSecond {
			return DownloadProgressFormatting.byteRate(rate)
		}
		if progress.isTransferStalled { return "Waiting for network…" }
		return nil
	}

	static func accessibilityValue(
		for progress: DownloadProgress?,
		detail: String?,
		isPaused: Bool
	) -> String {
		var values: [String] = []
		if let detail { values.append(detail) }
		if let transferDetail = transferDetail(for: progress, isPaused: isPaused) {
			values.append(transferDetail)
		}
		return values.joined(separator: ", ")
	}
}
