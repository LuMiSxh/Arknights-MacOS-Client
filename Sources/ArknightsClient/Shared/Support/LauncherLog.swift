// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Appends to a size-capped file the launcher and Wine layers share, so "Report a Problem"
/// and Settings → Logs always have one place to find recent diagnostic history.
///
/// Logging never suspends the caller: entries are timestamped immediately and written in call
/// order on one serial queue. Use `flush()` when a caller needs earlier entries on disk.
final class LauncherLog: Sendable {
	fileprivate enum Level: String {
		case debug = "DEBUG"
		case info = "INFO"
		case error = "ERROR"
	}

	private let queue = DispatchQueue(label: "com.lumisxh.arknights-client.log", qos: .utility)
	private let writer: LauncherLogWriter

	init(
		fileURL: URL,
		maximumFileSize: Int = AppConstants.Logging.maximumFileSize,
		maximumMessageBytes: Int = AppConstants.Logging.maximumMessageBytes
	) {
		precondition(maximumMessageBytes + 128 <= maximumFileSize)
		writer = LauncherLogWriter(
			fileURL: fileURL,
			maximumFileSize: maximumFileSize,
			maximumMessageBytes: maximumMessageBytes
		)
	}

	func debug(_ message: String) {
		enqueue(.debug, message)
	}

	func info(_ message: String) {
		enqueue(.info, message)
	}

	func error(_ message: String) {
		enqueue(.error, message)
	}

	/// Ensures the log file exists after every earlier entry has been written.
	func prepare() async {
		await perform { $0.prepare() }
	}

	/// Returns once every earlier entry has been written.
	func flush() async {
		await perform { _ in }
	}

	private func enqueue(_ level: Level, _ message: String) {
		let date = Date()
		queue.async { [writer] in writer.write(level, message, at: date) }
	}

	private func perform(_ work: @escaping @Sendable (LauncherLogWriter) -> Void) async {
		await withCheckedContinuation { continuation in
			queue.async { [writer] in
				work(writer)
				continuation.resume()
			}
		}
	}
}

/// Owns the file and formatter; only ever used on `LauncherLog`'s serial queue.
private final class LauncherLogWriter: @unchecked Sendable {
	private let fileURL: URL
	private let fileManager = FileManager.default
	private let formatter = ISO8601DateFormatter()
	private let maximumFileSize: Int
	private let maximumMessageBytes: Int

	init(fileURL: URL, maximumFileSize: Int, maximumMessageBytes: Int) {
		self.fileURL = fileURL
		self.maximumFileSize = maximumFileSize
		self.maximumMessageBytes = maximumMessageBytes
		formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
	}

	func prepare() {
		do {
			try prepareFile(forAppending: 0)
		} catch {
			reportWriteFailure()
		}
	}

	func write(_ level: LauncherLog.Level, _ message: String, at date: Date) {
		do {
			let sanitized = boundedMessage(message.replacingOccurrences(of: "\n", with: " "))
			let line = "\(formatter.string(from: date)) [\(level.rawValue)] \(sanitized)\n"
			let data = Data(line.utf8)
			try prepareFile(forAppending: data.count)

			let handle = try FileHandle(forWritingTo: fileURL)
			defer { handle.closeFile() }
			try handle.seekToEnd()
			try handle.write(contentsOf: data)
		} catch {
			reportWriteFailure()
		}
	}

	private func boundedMessage(_ message: String) -> String {
		guard message.lengthOfBytes(using: .utf8) > maximumMessageBytes else { return message }

		let marker = AppConstants.Logging.truncationMarker
		let prefixLimit = maximumMessageBytes - marker.lengthOfBytes(using: .utf8)
		var prefix = ""
		var prefixBytes = 0

		for scalar in message.unicodeScalars {
			let scalarBytes = scalar.utf8.count
			guard prefixBytes + scalarBytes <= prefixLimit else { break }
			prefix.unicodeScalars.append(scalar)
			prefixBytes += scalarBytes
		}

		return prefix + marker
	}

	private func prepareFile(forAppending byteCount: Int) throws {
		try fileManager.createDirectory(
			at: fileURL.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)

		if fileManager.fileExists(atPath: fileURL.path) {
			let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
			let size = max((attributes[.size] as? NSNumber)?.intValue ?? 0, 0)
			if size >= maximumFileSize || byteCount > maximumFileSize - size {
				let previousURL = fileURL.deletingPathExtension()
					.appendingPathExtension("previous.log")
				if fileManager.fileExists(atPath: previousURL.path) {
					try fileManager.removeItem(at: previousURL)
				}
				try fileManager.moveItem(at: fileURL, to: previousURL)
			}
		}

		if !fileManager.fileExists(atPath: fileURL.path),
			!fileManager.createFile(atPath: fileURL.path, contents: nil)
		{
			throw LauncherError.cannotCreateFile(fileURL)
		}
	}

	private func reportWriteFailure() {
		NSLog("ArknightsClient could not write a diagnostic log entry.")
	}
}
