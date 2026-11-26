// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

extension GameSessionController {
	nonisolated static func launchDiagnostics(
		sessionID: UUID,
		region: GameRegion,
		lane: RuntimeLane,
		options: GameLaunchOptions,
		batterySaver: Bool,
		graphicsDiagnosticsEnabled: Bool
	) -> LogFields {
		[
			"session": sessionID,
			"server": region.rawValue,
			"lane": lane.rawValue,
			"usesGameSettings": options.usesGameSettings,
			"displayMode": options.displayMode.rawValue,
			"resolution": options.resolution.storageValue,
			"fullscreenResolution": options.fullscreenResolution.storageValue,
			"windowSize": options.windowSize.storageValue,
			"rendering": options.renderingMode.rawValue,
			"metalHUD": options.usesMetalPerformanceHUD,
			"gameMode": options.usesGameMode,
			"synchronization": options.synchronizationMode.rawValue,
			"frameRateLimit": options.frameRateLimit.rawValue,
			"batterySaver": batterySaver,
			"graphicsDiagnostics": graphicsDiagnosticsEnabled,
		]
	}

	nonisolated static func launchDuration(since start: Date, now: Date = .now) -> Duration {
		.seconds(max(0, now.timeIntervalSince(start)))
	}

	// Reads the crash report and log tail off the caller's actor.
	@concurrent
	static func collectExitDiagnostics(
		_ exit: WineProcessExit,
		since: Date?,
		logURL: URL?,
		log: LauncherLog
	) async -> LogFields {
		exitDiagnostics(exit, since: since, logURL: logURL, log: log)
	}

	nonisolated static func exitDiagnostics(
		_ exit: WineProcessExit,
		since: Date?,
		logURL: URL?,
		log: LauncherLog
	) -> LogFields {
		let crashReport = logURL == nil ? nil : recentCrashReportPath(near: .now, log: log)
		let tail = logURL.flatMap {
			FileTail.read(of: $0, maximumBytes: AppConstants.Logging.wineLogTailBytes)
		}
		return [
			"exitStatus": exit.status,
			"reason": reasonDescription(exit.reason),
			"elapsed": since.map { Duration.seconds(max(0, Date().timeIntervalSince($0))) },
			"crashReport": crashReport,
			"detail": tail,
		]
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
		in directory: URL = AppPaths.systemCrashReportsDirectory,
		window: Duration = .seconds(AppConstants.Logging.crashReportSearchWindow),
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
			log.error(.diagnostics, "crash-report-list-failed", error: error)
			return nil
		}
		return
			entries
			.filter {
				$0.lastPathComponent.hasPrefix(
					"\(AppConstants.Runtime.applicationName)-")
			}
			.compactMap { url -> (URL, Date)? in
				do {
					guard
						let modified = try url.resourceValues(
							forKeys: [.contentModificationDateKey]
						).contentModificationDate
					else { return nil }
					return (url, modified)
				} catch {
					log.warning(
						.diagnostics, "crash-report-date-failed",
						["file": url.lastPathComponent], error: error)
					return nil
				}
			}
			.filter { Duration.seconds(abs($0.1.timeIntervalSince(date))) <= window }
			.max { $0.1 < $1.1 }?
			.0.path
	}
}
