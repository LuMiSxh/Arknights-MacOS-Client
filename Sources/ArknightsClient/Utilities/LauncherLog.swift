// SPDX-License-Identifier: MPL-2.0

import Foundation

actor LauncherLog {
	private enum Level: String {
		case info = "INFO"
		case error = "ERROR"
	}

	private let fileURL: URL
	private let fileManager: FileManager
	private let formatter = ISO8601DateFormatter()
	private let maximumFileSize = 4 * 1_024 * 1_024

	init(fileURL: URL, fileManager: FileManager = .default) {
		self.fileURL = fileURL
		self.fileManager = fileManager
		formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
	}

	func info(_ message: String) {
		write(.info, message)
	}

	func error(_ message: String) {
		write(.error, message)
	}

	func prepare() {
		do {
			try prepareFile()
		} catch {
			// Diagnostics must never interrupt launcher work.
		}
	}

	private func write(_ level: Level, _ message: String) {
		do {
			try prepareFile()
			let timestamp = formatter.string(from: Date())
			let sanitized = message.replacingOccurrences(of: "\n", with: " ")
			let line = "\(timestamp) [\(level.rawValue)] \(sanitized)\n"
			guard let data = line.data(using: .utf8) else { return }

			let handle = try FileHandle(forWritingTo: fileURL)
			defer { try? handle.close() }
			try handle.seekToEnd()
			try handle.write(contentsOf: data)
		} catch {
			// Diagnostics must never interrupt launcher work.
		}
	}

	private func prepareFile() throws {
		try fileManager.createDirectory(
			at: fileURL.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)

		if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
			let size = attributes[.size] as? NSNumber,
			size.intValue >= maximumFileSize
		{
			let previousURL = fileURL.deletingPathExtension().appendingPathExtension("previous.log")
			if fileManager.fileExists(atPath: previousURL.path) {
				try fileManager.removeItem(at: previousURL)
			}
			try fileManager.moveItem(at: fileURL, to: previousURL)
		}

		if !fileManager.fileExists(atPath: fileURL.path),
			!fileManager.createFile(atPath: fileURL.path, contents: nil)
		{
			throw LauncherError.cannotCreateFile(fileURL)
		}
	}
}
