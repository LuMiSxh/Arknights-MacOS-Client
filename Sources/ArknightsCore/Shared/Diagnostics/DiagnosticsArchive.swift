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

	package init(
		logFiles: [URL],
		sdkLogDirectory: URL,
		publisher: GamePublisher,
		environment: String,
		readme: String,
		baseName: String,
		directory: URL,
		redaction: DiagnosticsRedaction,
		log: LauncherLog
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
		for url in logFiles where FileManager.default.fileExists(atPath: url.path) {
			items.append(
				.init(archivePath: "Logs/\(url.lastPathComponent)", content: .redactedLog(url)))
		}
		// The SDK logs and the runtime pin are optional: a failure here must not cancel the archive.
		do {
			items.append(
				contentsOf: try Self.sdkLogItems(in: sdkLogDirectory, publisher: publisher))
		} catch {
			log.error("SDK logs skipped: \(launcherDiagnosticDescription(for: error))")
		}
		do {
			let runtimeConfiguration = try BundledResource.runtimeConfiguration.url()
			items.append(.init(archivePath: "RUNTIME.json", content: .file(runtimeConfiguration)))
		} catch {
			log.error("RUNTIME.json skipped: \(launcherDiagnosticDescription(for: error))")
		}
		items.append(.init(archivePath: "environment.txt", content: .text(environment)))
		return items
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
