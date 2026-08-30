// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

/// Shared low-level file operations behind `GameCompatibilityComponent` implementations.
/// Each component keeps its own install/restore orchestration, error messages, and recovery
/// rules; only the mechanical parts that are byte-for-byte identical across components live
/// here, so the two never drift out of sync on the same primitive.
enum GameShimIO {
	static func containsMarker(at url: URL, marker: Data, maximumSize: Int) throws -> Bool {
		guard maximumSize >= 0, maximumSize < Int.max else { return false }
		let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
		guard descriptor >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
		defer { _ = close(descriptor) }
		var status = stat()
		guard fstat(descriptor, &status) == 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		guard status.st_mode & S_IFMT == S_IFREG,
			status.st_nlink == 1,
			status.st_uid == geteuid()
		else { return false }
		guard status.st_size >= 0, status.st_size <= Int64(maximumSize) else { return false }
		let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
		let data = try handle.read(upToCount: maximumSize + 1) ?? Data()
		guard data.count <= maximumSize else { return false }
		return data.range(of: marker) != nil
	}

	static func removeStaleTemporaryFiles(
		in directory: URL,
		matchingPrefixes prefixes: [String],
		fileManager: FileManager
	) throws {
		guard fileManager.fileExists(atPath: directory.path) else { return }
		for url in try fileManager.contentsOfDirectory(
			at: directory,
			includingPropertiesForKeys: nil
		) where prefixes.contains(where: { url.lastPathComponent.hasPrefix($0) }) {
			try fileManager.removeItem(at: url)
		}
	}

	/// Swaps `helperURL` for `shimURL`, first backing up whatever is currently
	/// there (the official helper on a first install, or a previous shim on upgrade) to
	/// `backupURL`. `installCompanions` runs only once the helper is in place; if it or the
	/// helper move itself fails, the helper is restored from its backup before rethrowing.
	static func swapHelper(
		at helperURL: URL,
		with shimURL: URL,
		backupURL: URL,
		isCurrentlyInstalledShim: Bool,
		temporaryPrefix: String,
		previousPrefix: String,
		fileManager: FileManager,
		installCompanions: () throws -> Void
	) throws {
		let directory = helperURL.deletingLastPathComponent()
		let temporaryURL = directory.appending(path: "\(temporaryPrefix)\(UUID().uuidString)")
		let previousURL = directory.appending(path: "\(previousPrefix)\(UUID().uuidString)")
		defer {
			try? fileManager.removeItem(at: temporaryURL)
			try? fileManager.removeItem(at: previousURL)
		}
		try fileManager.copyItem(at: shimURL, to: temporaryURL)
		if isCurrentlyInstalledShim {
			try fileManager.moveItem(at: helperURL, to: previousURL)
		} else {
			if fileManager.fileExists(atPath: backupURL.path) {
				try fileManager.removeItem(at: backupURL)
			}
			try fileManager.moveItem(at: helperURL, to: backupURL)
		}
		do {
			try fileManager.moveItem(at: temporaryURL, to: helperURL)
			try installCompanions()
		} catch {
			let operationError = error
			var rollbackErrors: [String] = []
			if fileManager.fileExists(atPath: helperURL.path) {
				do { try fileManager.removeItem(at: helperURL) } catch {
					rollbackErrors.append(error.localizedDescription)
				}
			}
			let restoreURL =
				fileManager.fileExists(atPath: previousURL.path) ? previousURL : backupURL
			do {
				try fileManager.moveItem(at: restoreURL, to: helperURL)
			} catch {
				rollbackErrors.append(error.localizedDescription)
			}
			if !rollbackErrors.isEmpty {
				throw GameShimRollbackError(
					operationDescription: operationError.localizedDescription,
					rollbackDescriptions: rollbackErrors
				)
			}
			throw operationError
		}
	}

	/// Replaces `destinationURL` with `sourceURL`; the caller-provided backup restores the
	/// destination if copying or moving the replacement fails.
	static func replaceWithBackup(
		destinationURL: URL,
		sourceURL: URL,
		backupURL: URL,
		temporaryName: String,
		fileManager: FileManager
	) throws {
		let temporaryURL = destinationURL.deletingLastPathComponent().appending(path: temporaryName)
		defer { try? fileManager.removeItem(at: temporaryURL) }
		do {
			try fileManager.copyItem(at: sourceURL, to: temporaryURL)
			try fileManager.moveItem(at: temporaryURL, to: destinationURL)
			try? fileManager.removeItem(at: backupURL)
		} catch {
			let operationError = error
			var rollbackErrors: [String] = []
			if fileManager.fileExists(atPath: destinationURL.path) {
				do { try fileManager.removeItem(at: destinationURL) } catch {
					rollbackErrors.append(error.localizedDescription)
				}
			}
			if fileManager.fileExists(atPath: backupURL.path) {
				do {
					try fileManager.moveItem(at: backupURL, to: destinationURL)
				} catch {
					rollbackErrors.append(error.localizedDescription)
				}
			}
			if !rollbackErrors.isEmpty {
				throw GameShimRollbackError(
					operationDescription: operationError.localizedDescription,
					rollbackDescriptions: rollbackErrors
				)
			}
			throw operationError
		}
	}
}
