// SPDX-License-Identifier: MPL-2.0

import Foundation

extension GameInstaller {
	func finishDownload(
		_ item: ManifestFile,
		partial: URL,
		destination: URL,
		installDirectory: URL,
		countedBytes: Int64,
		networkBytes: Int64,
		counter: ProgressCounter,
		progress: @escaping ProgressHandler
	) async throws {
		try assertNoSymbolicLinks(from: installDirectory, through: partial)
		try assertNoSymbolicLinks(from: installDirectory, through: destination)
		let actualSize = try fileSize(at: partial) ?? 0
		guard actualSize == item.byteCount else {
			throw LauncherError.downloadedSizeMismatch(
				path: item.path,
				expected: item.byteCount,
				actual: actualSize
			)
		}
		let checksum = try ManifestChecksum.checksum(of: partial, expected: item.hash)
		guard ManifestChecksum.matches(checksum, expected: item.hash) else {
			try fileManager.removeItem(at: partial)
			await progress(
				await counter.remove(
					bytes: countedBytes,
					networkBytes: networkBytes,
					file: item.path
				)
			)
			throw LauncherError.checksumMismatch(
				path: item.path, expected: item.hash, actual: checksum)
		}
		if fileManager.fileExists(atPath: destination.path) {
			try fileManager.removeItem(at: destination)
		}
		try fileManager.moveItem(at: partial, to: destination)
	}

	func fileSize(at url: URL) throws -> Int64? {
		do {
			let attributes = try fileManager.attributesOfItem(atPath: url.path)
			return (attributes[.size] as? NSNumber)?.int64Value
		} catch let error as CocoaError
			where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile
		{
			return nil
		} catch let error as POSIXError where error.code == .ENOENT {
			return nil
		}
	}
}
