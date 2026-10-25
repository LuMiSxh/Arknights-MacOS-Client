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
			let archive = try await DiagnosticsBundle.write(
				diagnosticsItems(),
				readme: diagnosticsReadme,
				named: Self.diagnosticsBaseName(),
				to: paths.diagnosticsDirectory,
				redaction: DiagnosticsRedaction(
					homeDirectory: NSHomeDirectory(), userName: NSUserName()),
				reportCleanupFailure: {
					log.error(
						"Diagnostics cleanup failed: \(launcherDiagnosticDescription(for: $0))")
				}
			)
			log.info("Diagnostics archive written: \(archive.lastPathComponent)")
			NSWorkspace.shared.activateFileViewerSelecting([archive])
		} catch is CancellationError {
			log.info("Diagnostics archive cancelled")
		} catch {
			lifecycle.show(
				DiagnosticsError(detail: launcherDiagnosticDescription(for: error)),
				context: "Diagnostics archive")
		}
	}

	private func diagnosticsItems() -> [DiagnosticsBundle.Item] {
		var items: [DiagnosticsBundle.Item] = []
		let logs = [
			paths.launcherLogFile,
			paths.runtimeLogFile(for: installation.region),
			paths.unityLogFile,
			paths.chromiumLogFile,
		]
		for url in logs where FileManager.default.fileExists(atPath: url.path) {
			items.append(
				.init(archivePath: "Logs/\(url.lastPathComponent)", content: .redactedLog(url)))
		}
		if let runtimeConfiguration = Bundle.main.url(
			forResource: "RUNTIME", withExtension: "json")
		{
			items.append(.init(archivePath: "RUNTIME.json", content: .file(runtimeConfiguration)))
		}
		items.append(.init(archivePath: "environment.txt", content: .text(environmentSummary)))
		return items
	}

	private var environmentSummary: String {
		let options = settings.launchOptions
		let metalFX =
			gameSession.metalFXSpatialUpscalingSupported.map {
				$0 ? "supported" : "unsupported"
			} ?? "unknown"
		let installed = installation.installedRegions.map(\.rawValue).sorted().joined(
			separator: ", ")
		let lines = [
			"Arknights Client \(IssueReportURL.appVersion)",
			IssueReportURL.diagnosticsEnvironment,
			"Runtime: \(gameSession.runtimeName ?? "unknown")",
			"MetalFX spatial upscaling: \(metalFX)",
			"Region: \(installation.region.rawValue)",
			"Display mode: \(String(describing: options.displayMode))",
			"Window size: \(options.windowSize.displayName)",
			"Fullscreen resolution: \(String(describing: options.fullscreenResolution))",
			"Rendering: \(String(describing: options.renderingMode))",
			"Cursor: \(settings.usesHardwareCursor ? "macOS" : "Game")",
			"Synchronization: \(String(describing: options.synchronizationMode))",
			"Installed regions: \(installed.isEmpty ? "none" : installed)",
		]
		return lines.joined(separator: "\n") + "\n"
	}

	private var diagnosticsReadme: String {
		"""
		# Arknights Client diagnostics

		This folder was written by Arknights Client \(IssueReportURL.appVersion).

		- `environment.txt`: app, runtime, display, and system details.
		- `Logs/`: the launcher log, the game runtime log, the Unity log, and the browser log,
		  when each exists.
		- `RUNTIME.json`: the runtime pin the app was built with.

		The archive is not uploaded anywhere.
		The app redacts your home folder path, your user name, and URL query strings in the logs.
		The logs can still contain other file paths, server names, and account details.
		Review the archive before you share it.
		"""
	}

	private static func diagnosticsBaseName(now: Date = .now) -> String {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.dateFormat = "yyyy-MM-dd-HHmmss"
		return "Arknights-Client-Diagnostics-\(formatter.string(from: now))"
	}
}
