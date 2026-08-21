// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Appends to a size-capped file the launcher and Wine layers share, so "Report a Problem"
/// and Settings → Logs always have one place to find recent diagnostic history.
actor LauncherLog {
	private enum Level: String {
		case debug = "DEBUG"
		case info = "INFO"
		case error = "ERROR"
	}

	private let fileURL: URL
	private let fileManager: FileManager
	private let formatter = ISO8601DateFormatter()
	private let maximumFileSize: Int
	private let maximumMessageBytes: Int

	init(
		fileURL: URL,
		fileManager: FileManager = .default,
		maximumFileSize: Int = AppConstants.Logging.maximumFileSize,
		maximumMessageBytes: Int = AppConstants.Logging.maximumMessageBytes
	) {
		precondition(maximumMessageBytes + 128 <= maximumFileSize)
		self.fileURL = fileURL
		self.fileManager = fileManager
		self.maximumFileSize = maximumFileSize
		self.maximumMessageBytes = maximumMessageBytes
		formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
	}

	func debug(_ message: String) {
		write(.debug, message)
	}

	func info(_ message: String) {
		write(.info, message)
	}

	func error(_ message: String) {
		write(.error, message)
	}

	func prepare() {
		do {
			try prepareFile(forAppending: 0)
		} catch {
			reportWriteFailure()
		}
	}

	private func write(_ level: Level, _ message: String) {
		do {
			let sanitized = boundedMessage(message.replacingOccurrences(of: "\n", with: " "))
			let timestamp = formatter.string(from: Date())
			let line = "\(timestamp) [\(level.rawValue)] \(sanitized)\n"
			guard let data = line.data(using: .utf8) else { return }
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
			let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
			if size + byteCount > maximumFileSize {
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
