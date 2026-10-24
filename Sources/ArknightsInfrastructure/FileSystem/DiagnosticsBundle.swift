// SPDX-License-Identifier: MPL-2.0

import Foundation

enum DiagnosticsBundleError: LocalizedError {
	case unsafeArchivePath(String)
	case missingSource(URL)
	case archiveFailed(Int32)

	var errorDescription: String? {
		switch self {
		case .unsafeArchivePath(let path):
			"Diagnostics path must stay inside the archive: \(path)"
		case .missingSource(let url):
			"A diagnostics source is missing: \(url.path)"
		case .archiveFailed(let status):
			"ditto exited with status \(status)"
		}
	}
}

/// Lays collected support files out in one folder and compresses that folder with `ditto`.
///
/// The caller decides what to collect, so this type knows nothing about logs or preferences.
/// It writes into a private staging folder first, so a failure never leaves a partial archive
/// under the name the user sees.
package enum DiagnosticsBundle {
	package struct Item: Sendable {
		package enum Content: Sendable {
			/// An existing file to copy into the archive.
			case file(URL)
			/// Text to write at `archivePath`.
			case text(String)
		}

		package let archivePath: String
		package let content: Content

		package init(archivePath: String, content: Content) {
			self.archivePath = archivePath
			self.content = content
		}
	}

	@concurrent
	package static func write(
		_ items: [Item],
		readme: String,
		named baseName: String,
		to directory: URL,
		fileManager: FileManager = .default
	) async throws -> URL {
		for item in items {
			try validate(archivePath: item.archivePath)
		}

		let staging = fileManager.temporaryDirectory.appending(
			path: ".\(baseName)-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
		// Best-effort cleanup of the private staging folder; the archive is already written.
		defer { try? fileManager.removeItem(at: staging) }

		for item in items {
			let destination = staging.appending(path: item.archivePath)
			try fileManager.createDirectory(
				at: destination.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
			switch item.content {
			case .file(let source):
				guard fileManager.fileExists(atPath: source.path) else {
					throw DiagnosticsBundleError.missingSource(source)
				}
				try fileManager.copyItem(at: source, to: destination)
			case .text(let text):
				try text.write(to: destination, atomically: true, encoding: .utf8)
			}
		}
		try readme.write(
			to: staging.appending(path: "README.md"), atomically: true, encoding: .utf8)

		try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
		let archive = directory.appending(path: "\(baseName).zip")
		if fileManager.fileExists(atPath: archive.path) {
			try fileManager.removeItem(at: archive)
		}

		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
		process.arguments = ["-c", "-k", "--sequesterRsrc", staging.path, archive.path]
		try process.run()
		process.waitUntilExit()
		guard process.terminationStatus == 0 else {
			throw DiagnosticsBundleError.archiveFailed(process.terminationStatus)
		}
		return archive
	}

	/// Rejects absolute paths and `..` so an item cannot write outside the staging folder.
	private static func validate(archivePath: String) throws {
		guard !archivePath.isEmpty, !archivePath.hasPrefix("/") else {
			throw DiagnosticsBundleError.unsafeArchivePath(archivePath)
		}
		let components = archivePath.split(separator: "/", omittingEmptySubsequences: false)
		guard !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
			throw DiagnosticsBundleError.unsafeArchivePath(archivePath)
		}
	}
}
