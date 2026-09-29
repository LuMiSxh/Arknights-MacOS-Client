// SPDX-License-Identifier: MPL-2.0

import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

private struct IconFileBackup {
	let destination: URL
	let backupURL: URL?
}

struct IconRollbackFailure: LauncherDiagnosticError {
	let original: any Error
	let rollbackErrors: [any Error]

	var errorDescription: String? {
		"The icon update failed, and the previous icons could not be fully restored. Check the launcher log."
	}

	var diagnosticDescription: String {
		let details = rollbackErrors.map(\.localizedDescription).joined(separator: "; ")
		return
			"Icon publication failed: \(original.localizedDescription). Rollback failures: \(details)"
	}
}

enum CustomizationImageIO {
	static func load(_ url: URL) async throws -> Data {
		try await Task.detached(priority: .userInitiated) {
			let values = try url.resourceValues(forKeys: [
				.fileSizeKey, .totalFileAllocatedSizeKey, .isRegularFileKey,
			])
			guard values.isRegularFile == true else {
				throw LauncherError.invalidCustomImage(url)
			}
			let allocatedSize = values.totalFileAllocatedSize ?? values.fileSize ?? 0
			guard
				allocatedSize > 0,
				allocatedSize <= AppConstants.Artwork.launcherMaximumBytes
			else { throw LauncherError.invalidCustomImage(url) }
			let data = try Data(contentsOf: url, options: .mappedIfSafe)
			try validate(data, source: url)
			return data
		}.value
	}

	static func prepareArtwork(_ data: Data, source: URL) async throws -> String {
		try await Task.detached(priority: .userInitiated) {
			try validate(data, source: source)
			let digest = SHA256.hash(data: data)
			return "custom.\(digest.map { String(format: "%02x", $0) }.joined())"
		}.value
	}

	static func stage(_ data: Data, at url: URL) async throws {
		try await Task.detached(priority: .userInitiated) {
			try FileManager.default.createDirectory(
				at: url.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
			try data.write(to: url, options: .atomic)
		}.value
	}

	static func stagedURL(for destination: URL, operationID: UUID) -> URL {
		destination.appendingPathExtension("stage.\(operationID.uuidString)")
	}

	static func commit(_ stagedURL: URL, to destination: URL) throws {
		let fileManager = FileManager.default
		if fileManager.fileExists(atPath: destination.path) {
			_ = try fileManager.replaceItemAt(destination, withItemAt: stagedURL)
		} else {
			try fileManager.moveItem(at: stagedURL, to: destination)
		}
	}

	static func publish(
		_ replacements: [(staged: URL, destination: URL)],
		using committer: CustomizationController.IconCommitter,
		log: LauncherLog
	) throws {
		let fileManager = FileManager.default
		var backups: [IconFileBackup] = []
		do {
			for replacement in replacements {
				guard fileManager.fileExists(atPath: replacement.destination.path) else {
					backups.append(
						IconFileBackup(destination: replacement.destination, backupURL: nil))
					continue
				}
				let backupURL = replacement.destination.appendingPathExtension(
					"backup.\(UUID().uuidString)"
				)
				backups.append(
					IconFileBackup(destination: replacement.destination, backupURL: backupURL))
				try fileManager.copyItem(at: replacement.destination, to: backupURL)
			}
		} catch {
			cleanupBackups(backups, preserving: [], log: log)
			throw error
		}

		var attempted: [Int] = []
		do {
			for index in replacements.indices {
				attempted.append(index)
				try committer(replacements[index].staged, replacements[index].destination)
			}
		} catch {
			let original = error
			var rollbackFailures: [(index: Int, error: any Error)] = []
			for index in attempted.reversed() {
				do {
					if let backupURL = backups[index].backupURL {
						try commit(backupURL, to: backups[index].destination)
					} else {
						try removeIfPresent(backups[index].destination)
					}
				} catch {
					rollbackFailures.append((index, error))
				}
			}
			let failedIndexes = Set(rollbackFailures.map(\.index))
			cleanupBackups(backups, preserving: failedIndexes, log: log)
			guard !rollbackFailures.isEmpty else { throw original }
			throw IconRollbackFailure(
				original: original,
				rollbackErrors: rollbackFailures.map(\.error)
			)
		}
		cleanupBackups(backups, preserving: [], log: log)
	}

	private static func cleanupBackups(
		_ backups: [IconFileBackup],
		preserving indexes: Set<Int>,
		log: LauncherLog
	) {
		for (index, backup) in backups.enumerated()
		where !indexes.contains(index) {
			if let backupURL = backup.backupURL { discard(backupURL, log: log) }
		}
	}

	static func discard(_ url: URL, log: LauncherLog) {
		guard FileManager.default.fileExists(atPath: url.path) else { return }
		do {
			try FileManager.default.removeItem(at: url)
		} catch {
			log.error("Failed to remove temporary icon file at \(url.path): \(error)")
		}
	}

	static func removeIfPresent(_ url: URL) throws {
		if FileManager.default.fileExists(atPath: url.path) {
			try FileManager.default.removeItem(at: url)
		}
	}

	static func encodePNG(fromTIFF data: Data) async throws -> Data {
		try await Task.detached(priority: .userInitiated) {
			guard
				let source = CGImageSourceCreateWithData(data as CFData, nil),
				let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
			else { throw LauncherError.cannotEncodeAppIcon }
			let output = NSMutableData()
			guard
				let destination = CGImageDestinationCreateWithData(
					output,
					UTType.png.identifier as CFString,
					1,
					nil
				)
			else { throw LauncherError.cannotEncodeAppIcon }
			CGImageDestinationAddImage(destination, image, nil)
			guard CGImageDestinationFinalize(destination) else {
				throw LauncherError.cannotEncodeAppIcon
			}
			return output as Data
		}.value
	}

	static func validate(_ data: Data, source: URL) throws {
		guard
			!data.isEmpty,
			data.count <= AppConstants.Artwork.launcherMaximumBytes,
			let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
			CGImageSourceGetCount(imageSource) == 1,
			let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
				as? [CFString: Any],
			let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
			let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
			dimensionsAreSafe(width: width, height: height)
		else { throw LauncherError.invalidCustomImage(source) }
	}

	static func dimensionsAreSafe(width: Int, height: Int) -> Bool {
		width > 0 && height > 0
			&& width <= AppConstants.Artwork.maximumDimension
			&& height <= AppConstants.Artwork.maximumDimension
			&& width <= AppConstants.Artwork.maximumPixels / height
	}
}
