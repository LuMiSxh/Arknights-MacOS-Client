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
	private let readme: String
	private let baseName: String
	private let directory: URL
	private let redaction: DiagnosticsRedaction
	private let log: LauncherLog
	private let runtimeConfigurationURL: URL?
	private let runtimeRoot: URL
	// `FileManager`'s shared query methods are thread-safe; the SDK does not mark the type Sendable.
	nonisolated(unsafe) private let fileManager: FileManager

	package init(
		logFiles: [URL],
		sdkLogDirectory: URL,
		publisher: GamePublisher,
		environment: String,
		readme: String,
		baseName: String,
		directory: URL,
		redaction: DiagnosticsRedaction,
		log: LauncherLog,
		runtimeRoot: URL,
		runtimeConfigurationURL: URL? = nil,
		fileManager: FileManager = .default
	) {
		self.logFiles = logFiles
		self.sdkLogDirectory = sdkLogDirectory
		self.publisher = publisher
		self.environment = environment
		self.readme = readme
		self.baseName = baseName
		self.directory = directory
		self.redaction = redaction
		self.log = log
		self.runtimeConfigurationURL = runtimeConfigurationURL
		self.runtimeRoot = runtimeRoot
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
				log.error("Diagnostics cleanup failed: \(launcherDiagnosticDescription(for: $0))")
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
		items.append(contentsOf: runtimeConfigurationItems())
		items.append(.init(archivePath: "environment.txt", content: .text(environment)))
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
			in: runtimeRoot, fileManager: fileManager)
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

	/// The multi-line `environment.txt` every archive carries. Kept here so every writer
	/// emits the same fields.
	package static func environmentSummary(
		options: GameLaunchOptions,
		usesHardwareCursor: Bool,
		metalFX: String,
		runtimeName: String?,
		region: GameRegion,
		installedRegions: [GameRegion]
	) -> String {
		let installed = installedRegions.map(\.rawValue).sorted().joined(separator: ", ")
		let lines = [
			"Arknights Client \(IssueReportURL.appVersion)",
			IssueReportURL.environment,
			"Runtime: \(runtimeName ?? "unknown")",
			"MetalFX spatial upscaling: \(metalFX)",
			"Region: \(region.rawValue)",
			"Display mode: \(String(describing: options.displayMode))",
			"Window size: \(options.windowSize.displayName)",
			"Fullscreen resolution: \(String(describing: options.fullscreenResolution))",
			"Rendering: \(String(describing: options.renderingMode))",
			"Cursor: \(usesHardwareCursor ? "macOS" : "Game")",
			"Synchronization: \(String(describing: options.synchronizationMode))",
			"Installed regions: \(installed.isEmpty ? "none" : installed)",
		]
		return lines.joined(separator: "\n") + "\n"
	}

	/// The README every archive carries, telling the user what is inside and what to review.
	package static var readme: String {
		"""
		# Arknights Client diagnostics

		This folder was written by Arknights Client \(IssueReportURL.appVersion).

		- `environment.txt`: app, runtime, display, and system details.
		- `Logs/`: the launcher log, the game runtime log, the Unity log, and the browser log,
		  when each exists.
		- `Logs/sdklogs/`: the publisher SDK logs for China, China (Bilibili), and Taiwan,
		  when they exist.
		- `RUNTIME.json`: the runtime pin the app was built with.

		The archive is not uploaded anywhere.
		The app redacts your home folder path, your user name, and URL query strings in the logs.
		The logs can still contain other file paths, server names, and account details.
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
}
