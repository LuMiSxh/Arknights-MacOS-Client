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
		lane: RuntimeLane,
		log: LauncherLog
	) async {
		log.attempt(.diagnostics, "sdk-log-collect") {
			try collect(
				publisher: publisher,
				sources: paths.sdkLogDirectories(for: publisher, lane: lane),
				destination: paths.collectedSDKLogDirectory(for: publisher)
			)
		}
	}

	/// Copies the tail of each known log from `sources`. When several profiles hold the same
	/// name, the most recently written copy wins.
	static func collect(
		publisher: GamePublisher,
		sources: [URL],
		destination: URL,
		maximumBytes: Int = AppConstants.Logging.sdkLogMaximumBytes,
		fileManager: FileManager = .default
	) throws {
		guard publisher != .yostar else { return }
		var created = false
		for name in fileNames {
			var newest: (file: URL, modified: Date)?
			for source in sources {
				let file = source.appending(path: name)
				guard let modified = try regularFileModificationDate(of: file) else { continue }
				if newest.map({ modified > $0.modified }) ?? true { newest = (file, modified) }
			}
			guard let newest else { continue }
			let tail = try readTail(of: newest.file, maximumBytes: maximumBytes)
			if !created {
				try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
				created = true
			}
			try tail.write(to: destination.appending(path: name), options: .atomic)
		}
	}

	private static func regularFileModificationDate(of file: URL) throws -> Date? {
		let values: URLResourceValues
		do {
			values = try file.resourceValues(forKeys: [
				.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey,
			])
		} catch  where AppPaths.isMissingPathError(error) {
			return nil
		}
		guard values.isRegularFile == true, values.isSymbolicLink != true else { return nil }
		return values.contentModificationDate ?? .distantPast
	}

	private static func readTail(of file: URL, maximumBytes: Int) throws -> Data {
		// A failed read skips the close; the handle closes when it deallocates.
		let handle = try FileHandle(forReadingFrom: file)
		let size = try handle.seekToEnd()
		try handle.seek(toOffset: size > UInt64(maximumBytes) ? size - UInt64(maximumBytes) : 0)
		let tail = try handle.readToEnd() ?? Data()
		try handle.close()
		return tail
	}
}
