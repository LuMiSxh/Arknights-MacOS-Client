// SPDX-License-Identifier: MPL-2.0

import Foundation
import Synchronization

/// Appends to a size-capped file the launcher and Wine layers share, so "Report a Problem"
/// and Settings → Logs always have one place to find recent diagnostic history.
///
/// Logging never suspends the caller: entries are timestamped immediately and written in call
/// order on one serial queue. Use `prepare()` when a caller needs earlier entries on disk.
package final class LauncherLog: Sendable {
	fileprivate enum Level: String {
		case debug = "DEBUG"
		case info = "INFO"
		case warning = "WARN"
		case error = "ERROR"

		var padded: String {
			rawValue.padding(toLength: 5, withPad: " ", startingAt: 0)
		}
	}

	private let queue = DispatchQueue(label: "com.lumisxh.arknights-client.log", qos: .utility)
	private let writer: LauncherLogWriter
	private let debugEnabled = Mutex(false)
	private static let timestampStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

	/// Room for the timestamp, level, and newline around a message.
	private static let lineOverheadBytes = 128

	package init(
		fileURL: URL,
		maximumFileSize: Int = AppConstants.Logging.maximumFileSize,
		maximumMessageBytes: Int = AppConstants.Logging.maximumMessageBytes
	) {
		precondition(maximumMessageBytes + Self.lineOverheadBytes <= maximumFileSize)
		writer = LauncherLogWriter(
			fileURL: fileURL,
			maximumFileSize: maximumFileSize,
			maximumMessageBytes: maximumMessageBytes
		)
	}

	package var isDebugEnabled: Bool {
		debugEnabled.withLock { $0 }
	}

	package func setDebugEnabled(_ enabled: Bool) {
		debugEnabled.withLock { $0 = enabled }
	}

	package func debug(
		_ category: LogCategory, _ event: StaticString,
		_ fields: @autoclosure () -> LogFields = [:]
	) {
		guard isDebugEnabled else { return }
		enqueue(.debug, category: category, event: event, fields: fields())
	}

	package func info(
		_ category: LogCategory, _ event: StaticString, _ fields: LogFields = [:]
	) {
		enqueue(.info, category: category, event: event, fields: fields)
	}

	package func warning(
		_ category: LogCategory, _ event: StaticString, _ fields: LogFields = [:],
		error: (any Error)? = nil
	) {
		enqueue(.warning, category: category, event: event, fields: fields, error: error)
	}

	package func error(
		_ category: LogCategory, _ event: StaticString, _ fields: LogFields = [:],
		error: (any Error)? = nil
	) {
		enqueue(.error, category: category, event: event, fields: fields, error: error)
	}

	/// Runs best-effort work and logs a WARN entry with the error on failure.
	package func attempt(
		_ category: LogCategory, _ event: StaticString, _ work: () throws -> Void
	) {
		do {
			try work()
		} catch {
			warning(category, event, error: error)
		}
	}

	/// Ensures the log file exists after every earlier entry has been written.
	package func prepare() async {
		await perform { $0.prepare() }
	}

	private func enqueue(
		_ level: Level, category: LogCategory, event: StaticString, fields: LogFields,
		error: (any Error)? = nil
	) {
		var body = "\(category.rawValue) \(event)\(fields.rendered)"
		if let error {
			let rendered = logFields(for: error)
			body += " error=\(logFieldValue(rendered.id))"
			if let detail = rendered.detail {
				body += " detail=\(logFieldValue(detail))"
			}
		}
		write(level: level, body: body)
	}

	private func write(level: Level, body: String) {
		let line = "\(Self.timestampStyle.format(Date())) \(level.padded) \(body)"
		queue.async { [writer] in writer.write(line) }
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

/// Owns the log file descriptor and formatter; only ever used on `LauncherLog`'s serial queue.
///
/// Keeps one `O_APPEND` descriptor and the file size in memory. It reopens only when the file
/// rotates, when the path no longer names the open file (the user cleared the logs), or after
/// a failed write.
// `@unchecked`: every stored mutable member is touched only on `LauncherLog.queue` (serial).
private final class LauncherLogWriter: @unchecked Sendable {
	private let fileURL: URL
	private let fileManager = FileManager.default
	private let maximumFileSize: Int
	private let maximumMessageBytes: Int
	private var descriptor: Int32 = -1
	private var openedIdentity: FileIdentity?
	private var currentSize = 0

	private struct FileIdentity: Equatable {
		let device: dev_t
		let inode: ino_t
	}

	private enum LogFileError: Error {
		case cannotOpen(URL, errno: Int32)
		case cannotWrite(errno: Int32)
	}

	init(fileURL: URL, maximumFileSize: Int, maximumMessageBytes: Int) {
		self.fileURL = fileURL
		self.maximumFileSize = maximumFileSize
		self.maximumMessageBytes = maximumMessageBytes
	}

	deinit {
		closeDescriptor()
	}

	func prepare() {
		do {
			try prepareFile(forAppending: 0)
		} catch {
			reportWriteFailure()
		}
	}

	func write(_ line: String) {
		var flattened = String.UnicodeScalarView()
		for scalar in line.unicodeScalars {
			flattened.append(scalar.properties.generalCategory == .control ? " " : scalar)
		}
		let sanitized = boundedMessage(String(flattened))
		let bytes = Array((sanitized + "\n").utf8)
		do {
			do {
				try prepareFile(forAppending: bytes.count)
				try append(bytes)
			} catch {
				// The file may have vanished or the descriptor gone stale; reopen once.
				closeDescriptor()
				try prepareFile(forAppending: bytes.count)
				try append(bytes)
			}
		} catch {
			closeDescriptor()
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
		if descriptor >= 0, currentIdentity() != openedIdentity {
			closeDescriptor()
		}
		if descriptor < 0 {
			try openFile()
		}
		if exceedsLimit(adding: byteCount) {
			closeDescriptor()
			try rotate()
			try openFile()
		}
	}

	private func exceedsLimit(adding byteCount: Int) -> Bool {
		currentSize >= maximumFileSize || byteCount > maximumFileSize - currentSize
	}

	private func rotate() throws {
		let previousURL = AppPaths.previousLogFile(of: fileURL)
		guard fileManager.fileExists(atPath: fileURL.path) else { return }
		if fileManager.fileExists(atPath: previousURL.path) {
			try fileManager.removeItem(at: previousURL)
		}
		try fileManager.moveItem(at: fileURL, to: previousURL)
	}

	private func openFile() throws {
		try fileManager.createDirectory(
			at: fileURL.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		let opened = open(fileURL.path, O_WRONLY | O_APPEND | O_CREAT | O_CLOEXEC, 0o644)
		guard opened >= 0 else { throw LogFileError.cannotOpen(fileURL, errno: errno) }

		var status = stat()
		guard fstat(opened, &status) == 0 else {
			let code = errno
			close(opened)
			throw LogFileError.cannotOpen(fileURL, errno: code)
		}
		descriptor = opened
		openedIdentity = FileIdentity(device: status.st_dev, inode: status.st_ino)
		currentSize = max(Int(status.st_size), 0)
	}

	private func append(_ bytes: [UInt8]) throws {
		var offset = 0
		try bytes.withUnsafeBytes { buffer in
			guard let base = buffer.baseAddress else { return }
			while offset < buffer.count {
				let written = Darwin.write(descriptor, base + offset, buffer.count - offset)
				if written < 0 {
					if errno == EINTR { continue }
					throw LogFileError.cannotWrite(errno: errno)
				}
				offset += written
			}
		}
		currentSize += bytes.count
	}

	/// Identity of whatever the log path names now; `nil` when the file is gone.
	private func currentIdentity() -> FileIdentity? {
		var status = stat()
		guard stat(fileURL.path, &status) == 0 else { return nil }
		return FileIdentity(device: status.st_dev, inode: status.st_ino)
	}

	private func closeDescriptor() {
		guard descriptor >= 0 else { return }
		close(descriptor)
		descriptor = -1
		openedIdentity = nil
		currentSize = 0
	}

	private func reportWriteFailure() {
		NSLog("ArknightsClient could not write a diagnostic log entry.")
	}
}
