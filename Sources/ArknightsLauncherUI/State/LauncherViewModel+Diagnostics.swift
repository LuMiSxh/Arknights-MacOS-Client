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
		do {
			let archive = try await DiagnosticsBundle.write(
				diagnosticsItems(),
				readme: diagnosticsReadme,
				named: Self.diagnosticsBaseName(),
				to: diagnosticsDirectory
			)
			log.info("Diagnostics archive written: \(archive.lastPathComponent)")
			NSWorkspace.shared.activateFileViewerSelecting([archive])
		} catch {
			log.error("Diagnostics archive failed: \(error.localizedDescription)")
			lifecycle.show(error, context: "Diagnostics archive")
		}
	}

	private var diagnosticsDirectory: URL {
		FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
			?? paths.applicationSupportRoot
	}

	private func diagnosticsItems() -> [DiagnosticsBundle.Item] {
		var items: [DiagnosticsBundle.Item] = []
		let logs = paths.logsDirectory
		let logNames = [
			"launcher.log",
			installation.region.publisher.runtimeLogFileName,
			"unity.log",
			"chromium.log",
		]
		for name in logNames {
			let url = logs.appending(path: name)
			guard FileManager.default.fileExists(atPath: url.path) else { continue }
			items.append(.init(archivePath: "Logs/\(name)", content: .file(url)))
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

		The archive is not uploaded anywhere. Review it before you attach it to a report.
		Logs can contain file paths and server URLs.
		"""
	}

	private static func diagnosticsBaseName(now: Date = .now) -> String {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.dateFormat = "yyyy-MM-dd-HHmmss"
		return "Arknights-Client-Diagnostics-\(formatter.string(from: now))"
	}
}
