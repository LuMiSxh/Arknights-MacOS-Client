// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Appends to a size-capped file the launcher and Wine layers share, so "Report a Problem"
/// and Settings → Logs always have one place to find recent diagnostic history.
///
/// Logging never suspends the caller: entries are timestamped immediately and written in call
/// order on one serial queue. Use `flush()` when a caller needs earlier entries on disk.
package final class LauncherLog: Sendable {
	fileprivate enum Level: String {
		case debug = "DEBUG"
		case info = "INFO"
		case error = "ERROR"
	}

	private let queue = DispatchQueue(label: "com.lumisxh.arknights-client.log", qos: .utility)
	private let writer: LauncherLogWriter

	package init(
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

	package func debug(_ message: String) {
		enqueue(.debug, message)
	}

	package func info(_ message: String) {
		enqueue(.info, message)
	}

	package func error(_ message: String) {
		enqueue(.error, message)
	}

	/// Runs best-effort work and logs a failure with `context`; the caller continues either way.
	/// Use it only when the error is neither handled nor rethrown.
	package func attempt(_ context: String, _ work: () throws -> Void) {
		do {
			try work()
		} catch {
			self.error("\(context): \(launcherDiagnosticDescription(for: error))")
		}
	}

	/// Ensures the log file exists after every earlier entry has been written.
	package func prepare() async {
		await perform { $0.prepare() }
	}

	/// Returns once every earlier entry has been written.
	package func flush() async {
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

/// Owns the log file descriptor and formatter; only ever used on `LauncherLog`'s serial queue.
///
/// Keeps one `O_APPEND` descriptor and the file size in memory. It reopens only when the file
/// rotates, when the path no longer names the open file (the user cleared the logs), or after
/// a failed write.
private final class LauncherLogWriter: @unchecked Sendable {
	private let fileURL: URL
	private let fileManager = FileManager.default
	private let formatter = ISO8601DateFormatter()
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
		formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
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

	func write(_ level: LauncherLog.Level, _ message: String, at date: Date) {
		let sanitized = boundedMessage(message.replacingOccurrences(of: "\n", with: " "))
		let line = "\(formatter.string(from: date)) [\(level.rawValue)] \(sanitized)\n"
		let bytes = Array(line.utf8)
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
		let previousURL = fileURL.deletingPathExtension().appendingPathExtension("previous.log")
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
			while offset < buffer.count {
				let written = Darwin.write(
					descriptor, buffer.baseAddress! + offset, buffer.count - offset)
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
