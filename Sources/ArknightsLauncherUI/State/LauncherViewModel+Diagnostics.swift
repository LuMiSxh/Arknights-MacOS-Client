// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsInfrastructure
import Foundation

extension LauncherViewModel {
	/// Writes the logs and the current settings to a zip and shows it in Finder.
	///
	/// Nothing is uploaded. The user reviews the archive and decides whether to attach it.
	package func saveDiagnostics() async {
		guard !isSavingDiagnostics else { return }
		isSavingDiagnostics = true
		defer { isSavingDiagnostics = false }
		do {
			let log = log
			await storage.refreshSDKLogs()
			let publisher = installation.region.publisher
			let runtimeLog = paths.runtimeLogFile(for: installation.region)
			let archive = try await DiagnosticsArchive(
				logFiles: [
					paths.launcherLogFile,
					AppPaths.previousLogFile(of: paths.launcherLogFile),
					runtimeLog,
					AppPaths.previousLogFile(of: runtimeLog),
					AppPaths.previousSecondLogFile(of: runtimeLog),
					paths.unityLogFile,
					AppPaths.previousLogFile(of: paths.unityLogFile),
					AppPaths.previousSecondLogFile(of: paths.unityLogFile),
					paths.chromiumLogFile,
				],
				sdkLogDirectory: paths.collectedSDKLogDirectory(for: publisher),
				publisher: publisher,
				environment: await diagnosticsEnvironment().json(),
				gameDirectories: gameDirectories(),
				readme: DiagnosticsArchive.readme,
				baseName: Self.diagnosticsBaseName(),
				directory: paths.diagnosticsDirectory,
				redaction: DiagnosticsRedaction(
					homeDirectory: NSHomeDirectory(), userName: NSUserName()),
				log: log,
				applicationSupportRoot: paths.applicationSupportRoot,
				runtimeConfigurationURL: paths.installedRuntimeConfigurationURL(
					for: runtimeSelection.selectedLane)
			).write()
			log.info(.diagnostics, "archive-written", ["file": archive.lastPathComponent])
			NSWorkspace.shared.activateFileViewerSelecting([archive])
		} catch is CancellationError {
			log.info(.diagnostics, "archive-cancelled")
		} catch {
			lifecycle.show(
				DiagnosticsError(detail: launcherDiagnosticDescription(for: error)),
				context: "Diagnostics archive")
		}
	}

	private static func diagnosticsBaseName(now: Date = .now) -> String {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.dateFormat = "yyyy-MM-dd-HHmmss"
		return "Arknights-Client-Diagnostics-\(formatter.string(from: now))"
	}
}
