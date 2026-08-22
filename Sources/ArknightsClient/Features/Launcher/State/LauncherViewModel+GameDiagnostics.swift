// SPDX-License-Identifier: MPL-2.0

import Foundation

extension LauncherViewModel {
	nonisolated static func launchDiagnostics(
		sessionID: UUID,
		region: GameRegion,
		options: GameLaunchOptions,
		graphicsDiagnosticsEnabled: Bool
	) -> String {
		"Game launch requested; session=\(sessionID.uuidString); region=\(region.displayName); "
			+ "usesGameSettings=\(options.usesGameSettings); "
			+ "displayMode=\(options.displayMode.displayName); "
			+ "resolution=\(options.resolution.rawValue); "
			+ "highResolution=\(options.usesHighResolutionMode); "
			+ "metalHUD=\(options.usesMetalPerformanceHUD); "
			+ "gameMode=\(options.usesGameMode); "
			+ "synchronization=\(options.synchronizationMode.displayName); "
			+ "graphicsDiagnostics=\(graphicsDiagnosticsEnabled)"
	}

	nonisolated static func launchDuration(since start: Date, now: Date = .now) -> String {
		max(0, now.timeIntervalSince(start)).formatted(
			.number.locale(Locale(identifier: "en_US_POSIX")).precision(.fractionLength(2))
		) + "s"
	}

	/// Builds a compact diagnostic summary for a game-process exit: how long it
	/// ran, the raw exit status and reason, and, for anything that looks like a
	/// crash, a wine.log tail and any matching macOS crash report. Issue #17
	/// reported a crash with nothing but a bare exit status to go on.
	nonisolated static func exitDiagnostics(
		_ exit: WineProcessExit,
		since: Date?,
		logURL: URL?
	) -> String {
		var parts = ["status=\(exit.status)", "reason=\(Self.reasonDescription(exit.reason))"]
		if let since {
			parts.append("ranFor=\(launchDuration(since: since))")
		}
		guard let logURL else { return parts.joined(separator: " ") }
		if let crashReport = recentCrashReportPath(near: Date()) {
			parts.append("crashReport=\(crashReport)")
		}
		if let tail = FileTail.read(
			of: logURL,
			maximumBytes: AppConstants.Logging.wineLogTailBytes
		) {
			parts.append("wine.log tail: \(tail)")
		}
		return parts.joined(separator: " ")
	}

	/// `Process.TerminationReason` bridges to `NSTaskTerminationReason` and
	/// interpolates as an unreadable `NSTaskTerminationReason(rawValue: 2)`.
	private nonisolated static func reasonDescription(
		_ reason: Process.TerminationReason
	) -> String {
		switch reason {
		case .exit: "exit"
		case .uncaughtSignal: "uncaughtSignal"
		@unknown default: "unknown(\(reason.rawValue))"
		}
	}

	/// Wine renames the game process to "Arknights" (`WINEPRELOADERAPPNAME`), so a
	/// crash report for it is filed under that name in Diagnostic Reports.
	nonisolated static func recentCrashReportPath(
		near date: Date,
		in directory: URL = FileManager.default.homeDirectoryForCurrentUser
			.appending(path: "Library/Logs/DiagnosticReports", directoryHint: .isDirectory),
		window: TimeInterval = AppConstants.Logging.crashReportSearchWindow,
		fileManager: FileManager = .default
	) -> String? {
		guard
			let entries = try? fileManager.contentsOfDirectory(
				at: directory,
				includingPropertiesForKeys: [.contentModificationDateKey]
			)
		else { return nil }
		return
			entries
			.filter { $0.lastPathComponent.hasPrefix("Arknights-") }
			.compactMap { url -> (URL, Date)? in
				guard
					let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey])
						.contentModificationDate
				else { return nil }
				return (url, modified)
			}
			.filter { abs($0.1.timeIntervalSince(date)) <= window }
			.max { $0.1 < $1.1 }?
			.0.path
	}
}
