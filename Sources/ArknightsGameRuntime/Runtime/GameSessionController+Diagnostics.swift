// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

extension GameSessionController {
	nonisolated static func launchDiagnostics(
		sessionID: UUID,
		region: GameRegion,
		options: GameLaunchOptions,
		graphicsDiagnosticsEnabled: Bool
	) -> String {
		// One long `+` chain exceeds the type checker's budget once the option types are imported.
		let fields = [
			"session=\(sessionID.uuidString)",
			"region=\(region.displayName)",
			"usesGameSettings=\(options.usesGameSettings)",
			"displayMode=\(options.displayMode.displayName)",
			"resolution=\(options.resolution.storageValue)",
			"fullscreenResolution=\(options.fullscreenResolution.storageValue)",
			"windowSize=\(options.windowSize.width)x\(options.windowSize.height)",
			"rendering=\(options.renderingMode.rawValue)",
			"metalHUD=\(options.usesMetalPerformanceHUD)",
			"gameMode=\(options.usesGameMode)",
			"synchronization=\(options.synchronizationMode.displayName)",
			"frameRateLimit=\(options.frameRateLimit.rawValue)",
			"graphicsDiagnostics=\(graphicsDiagnosticsEnabled)",
		]
		return "Game launch requested; " + fields.joined(separator: "; ")
	}

	nonisolated static func launchDuration(since start: Date, now: Date = .now) -> String {
		max(0, now.timeIntervalSince(start)).formatted(
			.number.locale(Locale(identifier: "en_US_POSIX")).precision(.fractionLength(2))
		) + "s"
	}

	// Reads the crash report and log tail off the caller's actor.
	@concurrent
	static func collectExitDiagnostics(
		_ exit: WineProcessExit,
		since: Date?,
		logURL: URL?,
		log: LauncherLog
	) async -> String {
		exitDiagnostics(exit, since: since, logURL: logURL, log: log)
	}

	nonisolated static func exitDiagnostics(
		_ exit: WineProcessExit,
		since: Date?,
		logURL: URL?,
		log: LauncherLog
	) -> String {
		var parts = ["status=\(exit.status)", "reason=\(Self.reasonDescription(exit.reason))"]
		if let since { parts.append("ranFor=\(launchDuration(since: since))") }
		guard let logURL else { return parts.joined(separator: " ") }
		if let crashReport = recentCrashReportPath(near: .now, log: log) {
			parts.append("crashReport=\(crashReport)")
		}
		if let tail = FileTail.read(
			of: logURL,
			maximumBytes: AppConstants.Logging.wineLogTailBytes
		) {
			parts.append("\(logURL.lastPathComponent) tail: \(tail)")
		}
		return parts.joined(separator: " ")
	}

	private nonisolated static func reasonDescription(
		_ reason: Process.TerminationReason
	) -> String {
		switch reason {
		case .exit: "exit"
		case .uncaughtSignal: "uncaughtSignal"
		@unknown default: "unknown(\(reason.rawValue))"
		}
	}

	nonisolated static func recentCrashReportPath(
		near date: Date,
		log: LauncherLog,
		in directory: URL = FileManager.default.homeDirectoryForCurrentUser
			.appending(path: "Library/Logs/DiagnosticReports", directoryHint: .isDirectory),
		window: TimeInterval = AppConstants.Logging.crashReportSearchWindow,
		fileManager: FileManager = .default
	) -> String? {
		// A missing folder means there are no crash reports, which is not an error.
		guard fileManager.fileExists(atPath: directory.path) else { return nil }
		let entries: [URL]
		do {
			entries = try fileManager.contentsOfDirectory(
				at: directory,
				includingPropertiesForKeys: [.contentModificationDateKey]
			)
		} catch {
			log.error("Could not list crash reports: \(error.localizedDescription)")
			return nil
		}
		return
			entries
			.filter { $0.lastPathComponent.hasPrefix("Arknights-") }
			.compactMap { url -> (URL, Date)? in
				do {
					guard
						let modified = try url.resourceValues(
							forKeys: [.contentModificationDateKey]
						).contentModificationDate
					else { return nil }
					return (url, modified)
				} catch {
					log.error(
						"Could not read the date of \(url.lastPathComponent): \(error.localizedDescription)"
					)
					return nil
				}
			}
			.filter { abs($0.1.timeIntervalSince(date)) <= window }
			.max { $0.1 < $1.1 }?
			.0.path
	}
}
