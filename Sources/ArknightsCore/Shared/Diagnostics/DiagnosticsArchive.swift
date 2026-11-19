// SPDX-License-Identifier: MPL-2.0

import ArknightsInfrastructure
import Foundation

/// The support files that "Report a Problem" collects, and the archive that holds them.
///
/// The caller gathers the paths and text. This type checks which files exist, reads the optional
/// SDK logs and the bundled runtime pin, and writes the archive through `DiagnosticsBundle`.
/// Nothing is uploaded.
package struct DiagnosticsArchive: Sendable {
	private let logFiles: [URL]
	private let sdkLogDirectory: URL
	private let publisher: GamePublisher
	private let environment: String
	private let gameDirectories: [(region: GameRegion, directory: URL)]
	private let crashReportsDirectory: URL
	private let now: Date
	private let readme: String
	private let baseName: String
	private let directory: URL
	private let redaction: DiagnosticsRedaction
	private let log: LauncherLog
	private let runtimeConfigurationURL: URL?
	private let applicationSupportRoot: URL
	// `FileManager`'s shared query methods are thread-safe; the SDK does not mark the type Sendable.
	nonisolated(unsafe) private let fileManager: FileManager

	package init(
		logFiles: [URL],
		sdkLogDirectory: URL,
		publisher: GamePublisher,
		environment: String,
		gameDirectories: [(region: GameRegion, directory: URL)] = [],
		crashReportsDirectory: URL = AppPaths.systemCrashReportsDirectory,
		now: Date = .now,
		readme: String,
		baseName: String,
		directory: URL,
		redaction: DiagnosticsRedaction,
		log: LauncherLog,
		applicationSupportRoot: URL,
		runtimeConfigurationURL: URL? = nil,
		fileManager: FileManager = .default
	) {
		self.logFiles = logFiles
		self.sdkLogDirectory = sdkLogDirectory
		self.publisher = publisher
		self.environment = environment
		self.gameDirectories = gameDirectories
		self.crashReportsDirectory = crashReportsDirectory
		self.now = now
		self.readme = readme
		self.baseName = baseName
		self.directory = directory
		self.redaction = redaction
		self.log = log
		self.runtimeConfigurationURL = runtimeConfigurationURL
		self.applicationSupportRoot = applicationSupportRoot
		self.fileManager = fileManager
	}

	/// Writes the archive as `baseName.zip` in `directory`, or `baseName-2.zip` when that name is taken.
	@concurrent
	package func write() async throws -> URL {
		let log = self.log
		return try await DiagnosticsBundle.write(
			items(),
			readme: readme,
			named: baseName,
			to: directory,
			redaction: redaction,
			reportCleanupFailure: {
				log.error(
					"Diagnostics file skipped or cleanup failed:\(launcherDiagnosticDescription(for: $0))"
				)
			}
		)
	}

	private func items() -> [DiagnosticsBundle.Item] {
		var items: [DiagnosticsBundle.Item] = []
		for url in logFiles where fileManager.fileExists(atPath: url.path) {
			items.append(
				.init(archivePath: "Logs/\(url.lastPathComponent)", content: .redactedLog(url)))
		}
		// The SDK logs and the runtime pin are optional: a failure here must not cancel the archive.
		do {
			items.append(
				contentsOf: try Self.sdkLogItems(
					in: sdkLogDirectory, publisher: publisher, fileManager: fileManager))
		} catch {
			log.error("SDK logs skipped: \(launcherDiagnosticDescription(for: error))")
		}
		let cutoff = now.addingTimeInterval(-AppConstants.Diagnostics.recentFileWindow)
		for (region, directory) in gameDirectories {
			do {
				items.append(
					contentsOf: try Self.gameFolderItems(
						region: region, directory: directory, cutoff: cutoff,
						fileManager: fileManager))
			} catch {
				log.error(
					"Game folder logs skipped for \(region.rawValue): \(launcherDiagnosticDescription(for: error))"
				)
			}
		}
		do {
			items.append(
				contentsOf: try Self.crashReportItems(
					in: crashReportsDirectory,
					processRoots: [Bundle.main.bundleURL, applicationSupportRoot]
						+ gameDirectories.map(\.directory),
					cutoff: cutoff, fileManager: fileManager))
		} catch {
			log.error("Crash reports skipped: \(launcherDiagnosticDescription(for: error))")
		}
		items.append(contentsOf: runtimeConfigurationItems())
		// The facts hold no paths by design; redaction is the backstop for any free-form value.
		items.append(
			.init(archivePath: "environment.json", content: .redactedText(environment)))
		return items
	}

	/// The bundled or installed runtime pins as archive items. A pin that cannot be read is
	/// logged and omitted, never raised.
	private func runtimeConfigurationItems() -> [DiagnosticsBundle.Item] {
		let archiveName = "RUNTIME.json"
		let runtimeConfiguration: URL
		if let runtimeConfigurationURL {
			runtimeConfiguration = runtimeConfigurationURL
		} else {
			do {
				runtimeConfiguration = try BundledResource.runtimeConfiguration.url()
			} catch {
				log.error("\(archiveName) skipped: \(launcherDiagnosticDescription(for: error))")
				return []
			}
		}
		guard fileManager.fileExists(atPath: runtimeConfiguration.path) else {
			log.error("\(archiveName) skipped: \(runtimeConfiguration.path) does not exist")
			return []
		}
		let installed = AppPaths.installedRuntimeConfigurationURLs(
			applicationSupportRoot: applicationSupportRoot)
		if installed.isEmpty {
			return [.init(archivePath: archiveName, content: .file(runtimeConfiguration))]
		}
		let selected = runtimeConfiguration.standardizedFileURL
		var items: [DiagnosticsBundle.Item] = []
		var includedSelected = false
		for (lane, url) in installed
		where fileManager.fileExists(atPath: url.path) {
			if url.standardizedFileURL == selected { includedSelected = true }
			let name =
				url.standardizedFileURL == selected
				? archiveName : "RUNTIME-\(lane.rawValue).json"
			items.append(.init(archivePath: name, content: .file(url)))
		}
		if !includedSelected {
			items.append(.init(archivePath: archiveName, content: .file(runtimeConfiguration)))
		}
		return items
	}

	/// The README every archive carries, telling the user what is inside and what to review.
	package static var readme: String {
		"""
		# Arknights Client diagnostics

		This folder was written by Arknights Client \(IssueReportURL.appVersion).

		- `environment.json`: app, system, runtime, game, and settings details.
		- `Logs/`: the launcher log, the game runtime log, the Unity log, and the browser log,
		  when each exists. Each `*.previous.log` file holds the session before.
		- `Logs/sdklogs/`: the publisher SDK logs for China, China (Bilibili), and Taiwan,
		  when they exist. The China (Bilibili) logs from its game folder are included.
		- `Logs/CrashSight/`: the game crash reporter logs from the last 7 days, per server.
		- `CrashReports/`: macOS crash reports from the last 7 days for the app, Wine,
		  and the game processes.
		- `RUNTIME.json`: the runtime pin the app was built with.

		The archive does not contain save data, the game's event logs, or settings databases.
		The archive is not uploaded anywhere.
		The app redacts your home folder path, your user name, and URL query strings in text files.
		The files can still contain other file paths, server names, and account details.
		SDK logs can contain account IDs and access keys that redaction does not remove.
		Review the archive before you share it.
		"""
	}

	/// Lists the collected SDK logs for `publisher` as archive items, sorted by name.
	///
	/// Symlinks and subdirectories are skipped, so the archive never follows a link out of the logs folder.
	static func sdkLogItems(
		in directory: URL,
		publisher: GamePublisher,
		fileManager: FileManager = .default
	) throws -> [DiagnosticsBundle.Item] {
		guard fileManager.fileExists(atPath: directory.path) else { return [] }
		let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey]
		let files = try fileManager.contentsOfDirectory(
			at: directory, includingPropertiesForKeys: Array(keys))
		return try files.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { file in
			let values = try file.resourceValues(forKeys: keys)
			guard values.isRegularFile == true, values.isSymbolicLink != true else { return nil }
			return DiagnosticsBundle.Item(
				archivePath: "Logs/sdklogs/\(publisher.rawValue)/\(file.lastPathComponent)",
				content: .redactedLog(file))
		}
	}

	/// The game's own text logs: `CrashSightLog/` for every server, and the Bilibili platform
	/// logs for China (Bilibili). Only recent `.log` and `.txt` files are listed.
	static func gameFolderItems(
		region: GameRegion,
		directory: URL,
		cutoff: Date,
		fileManager: FileManager = .default
	) throws -> [DiagnosticsBundle.Item] {
		var sources = [("CrashSightLog", "Logs/CrashSight/\(region.serverIdentifier)")]
		if region == .chinaBilibili {
			let base = "Logs/sdklogs/\(region.serverIdentifier)/BLPlatform64"
			sources.append(("BLPlatform64", base))
			sources.append(("BLPlatform64/BLWebBrowser", "\(base)/BLWebBrowser"))
		}
		return try sources.flatMap { folder, archiveFolder in
			try DiagnosticsFileSelection.recentFiles(
				in: directory.appending(path: folder, directoryHint: .isDirectory),
				below: directory, extensions: ["log", "txt"], newerThan: cutoff,
				fileManager: fileManager
			).map {
				DiagnosticsBundle.Item(
					archivePath: "\(archiveFolder)/\($0.lastPathComponent)",
					content: .redactedLog($0))
			}
		}
	}

	/// Recent macOS crash reports of processes that run from `processRoots`: the app bundle, the
	/// app's support folder (runtime, game environments), and the game folders. Other apps'
	/// reports stay out, whatever their process is called.
	static func crashReportItems(
		in directory: URL,
		processRoots: [URL],
		cutoff: Date,
		fileManager: FileManager = .default
	) throws -> [DiagnosticsBundle.Item] {
		let roots = processRoots.map { $0.standardizedFileURL.path + "/" }
		return try DiagnosticsFileSelection.recentFiles(
			in: directory, extensions: ["ips"],
			matching: { report in
				guard let process = Self.processPath(ofCrashReportAt: report) else { return false }
				return roots.contains { process.hasPrefix($0) }
			},
			newerThan: cutoff, fileManager: fileManager
		).map {
			DiagnosticsBundle.Item(
				archivePath: "CrashReports/\($0.lastPathComponent)", content: .redactedLog($0))
		}
	}

	/// The `procPath` of a `.ips` report, read from its first few KB. A report that cannot be read is skipped.
	private static func processPath(ofCrashReportAt report: URL) -> String? {
		let head: Data
		do {
			// A failed read skips the close; the handle closes when it deallocates.
			let handle = try FileHandle(forReadingFrom: report)
			head =
				try handle.read(upToCount: AppConstants.Diagnostics.crashReportHeaderBytes)
				?? Data()
			try handle.close()
		} catch {
			return nil
		}
		let text = String(decoding: head, as: UTF8.self)
		guard let match = text.firstMatch(of: /"procPath"\s*:\s*"([^"]*)"/) else { return nil }
		return String(match.1).replacing("\\/", with: "/")
	}
}
