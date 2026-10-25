// SPDX-License-Identifier: MPL-2.0

import Foundation
import Synchronization

enum DiagnosticsBundleError: LocalizedError {
	case unsafeArchivePath(String)
	case missingSource(URL)
	case cannotCreateFile(URL)
	case archiveFailed(Int32)

	var errorDescription: String? {
		switch self {
		case .unsafeArchivePath(let path):
			"Diagnostics path must stay inside the archive: \(path)"
		case .missingSource(let url):
			"A diagnostics source is missing: \(url.path)"
		case .cannotCreateFile(let url):
			"Could not create a diagnostics file: \(url.path)"
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
			/// An existing file to copy into the archive unchanged.
			case file(URL)
			/// An existing text log to copy with `DiagnosticsRedaction` applied.
			case redactedLog(URL)
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

	private static let copyChunkBytes = 64 * 1_024
	private static let maximumLineBytes = 256 * 1_024
	private static let maximumLogBytes = 32 * 1_024 * 1_024
	private static let truncationNotice = "\n[diagnostics: log truncated]\n"

	/// Writes the archive as `baseName.zip`, or `baseName-2.zip` and so on when that name is taken.
	///
	/// `reportCleanupFailure` receives errors from best-effort cleanup that the caller cannot
	/// otherwise see.
	@concurrent
	package static func write(
		_ items: [Item],
		readme: String,
		named baseName: String,
		to directory: URL,
		redaction: DiagnosticsRedaction,
		reportCleanupFailure: @Sendable (any Error) -> Void,
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
		defer { remove(staging, using: fileManager, report: reportCleanupFailure) }

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
			case .redactedLog(let source):
				guard fileManager.fileExists(atPath: source.path) else {
					throw DiagnosticsBundleError.missingSource(source)
				}
				try copyRedacted(from: source, to: destination, redaction: redaction, fileManager)
			case .text(let text):
				try text.write(to: destination, atomically: true, encoding: .utf8)
			}
		}
		try readme.write(
			to: staging.appending(path: "README.md"), atomically: true, encoding: .utf8)

		try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
		let archive = availableArchive(named: baseName, in: directory, fileManager)
		do {
			let status = try await CancellableProcess(
				executable: URL(fileURLWithPath: "/usr/bin/ditto"),
				arguments: ["-c", "-k", "--sequesterRsrc", staging.path, archive.path]
			).run()
			try Task.checkCancellation()
			guard status == 0 else { throw DiagnosticsBundleError.archiveFailed(status) }
		} catch {
			remove(archive, using: fileManager, report: reportCleanupFailure)
			throw error
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

	private static func availableArchive(
		named baseName: String, in directory: URL, _ fileManager: FileManager
	) -> URL {
		var candidate = directory.appending(path: "\(baseName).zip")
		var suffix = 2
		while fileManager.fileExists(atPath: candidate.path) {
			candidate = directory.appending(path: "\(baseName)-\(suffix).zip")
			suffix += 1
		}
		return candidate
	}

	private static func remove(
		_ url: URL, using fileManager: FileManager, report: @Sendable (any Error) -> Void
	) {
		guard fileManager.fileExists(atPath: url.path) else { return }
		do {
			try fileManager.removeItem(at: url)
		} catch {
			report(error)
		}
	}

	/// Copies in bounded chunks that end at line breaks, so a large log never sits in memory.
	private static func copyRedacted(
		from source: URL, to destination: URL, redaction: DiagnosticsRedaction,
		_ fileManager: FileManager
	) throws {
		guard fileManager.createFile(atPath: destination.path, contents: nil) else {
			throw DiagnosticsBundleError.cannotCreateFile(destination)
		}
		let input = try FileHandle(forReadingFrom: source)
		defer { input.closeFile() }
		let output = try FileHandle(forWritingTo: destination)
		defer { output.closeFile() }

		func emit(_ bytes: Data) throws {
			let text = String(decoding: bytes, as: UTF8.self)
			try output.write(contentsOf: Data(redaction.redact(text).utf8))
		}

		var pending = Data()
		var consumed = 0
		while let chunk = try input.read(upToCount: copyChunkBytes), !chunk.isEmpty {
			consumed += chunk.count
			pending.append(chunk)
			if let lastNewline = pending.lastIndex(of: 0x0A) {
				try emit(pending[pending.startIndex...lastNewline])
				pending = Data(pending[(lastNewline + 1)...])
			} else if pending.count >= maximumLineBytes {
				try emit(pending)
				pending.removeAll(keepingCapacity: true)
			}
			if consumed >= maximumLogBytes {
				try emit(pending)
				try output.write(contentsOf: Data(truncationNotice.utf8))
				return
			}
		}
		try emit(pending)
	}
}

/// Runs a child process and terminates it when the awaiting task is cancelled.
private final class CancellableProcess: @unchecked Sendable {
	private struct State {
		var isRunning = false
		var isCancelled = false
	}

	private let process = Process()
	private let state = Mutex(State())

	init(executable: URL, arguments: [String]) {
		process.executableURL = executable
		process.arguments = arguments
	}

	func run() async throws -> Int32 {
		try await withTaskCancellationHandler {
			try await withCheckedThrowingContinuation {
				(continuation: CheckedContinuation<Int32, any Error>) in
				process.terminationHandler = {
					continuation.resume(returning: $0.terminationStatus)
				}
				do {
					try state.withLock { state in
						if state.isCancelled { throw CancellationError() }
						try process.run()
						state.isRunning = true
					}
				} catch {
					process.terminationHandler = nil
					continuation.resume(throwing: error)
				}
			}
		} onCancel: {
			let shouldTerminate = state.withLock { state in
				state.isCancelled = true
				return state.isRunning
			}
			if shouldTerminate, process.isRunning { process.terminate() }
		}
	}
}
