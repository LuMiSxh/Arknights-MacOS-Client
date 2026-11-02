// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

// Login and agreement errors of the China and Taiwan clients appear only in the publisher SDK
// logs, which live inside the Wine prefix. Copying them next to the launcher logs puts them
// into "Reveal logs" and bug reports. HGDownloadLog.log and HGEventLog.log are left out on purpose.
enum SDKLogCollector {
	static let fileNames = [
		"u8sdk_pc.log",
		"u8core_ui_pc.log",
		"u8sdk_bilibili_pc.log",
		"platfrom_process.log",  // The publisher's spelling.
		"HGWebview.log",
	]

	@concurrent
	static func collect(
		publisher: GamePublisher,
		paths: AppPaths,
		log: LauncherLog
	) async {
		log.attempt("Collecting SDK logs") {
			try collect(
				publisher: publisher,
				source: paths.sdkLogDirectory(for: publisher),
				destination: paths.collectedSDKLogDirectory(for: publisher)
			)
		}
	}

	static func collect(
		publisher: GamePublisher,
		source: URL,
		destination: URL,
		maximumBytes: Int = AppConstants.Logging.sdkLogMaximumBytes,
		fileManager: FileManager = .default
	) throws {
		guard publisher != .yostar else { return }
		var created = false
		for name in fileNames {
			let file = source.appending(path: name)
			guard let tail = try readTail(of: file, maximumBytes: maximumBytes) else { continue }
			if !created {
				try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
				created = true
			}
			try tail.write(to: destination.appending(path: name), options: .atomic)
		}
	}

	private static func readTail(of file: URL, maximumBytes: Int) throws -> Data? {
		let values: URLResourceValues
		do {
			values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
		} catch  where AppPaths.isMissingPathError(error) {
			return nil
		}
		guard values.isRegularFile == true, values.isSymbolicLink != true else { return nil }
		let handle = try FileHandle(forReadingFrom: file)
		defer { try? handle.close() }
		let size = try handle.seekToEnd()
		try handle.seek(toOffset: size > UInt64(maximumBytes) ? size - UInt64(maximumBytes) : 0)
		return try handle.readToEnd() ?? Data()
	}
}
