// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

// Shared file primitives for `GameCompatibilityComponent`s. Components keep their own
// orchestration and error messages.
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

	// The current helper moves aside first: the official helper on a first install goes to
	// `backupURL`; a previous shim moves to a unique sibling. `installCompanions` runs only
	// after the shim is in place, and any later failure restores the helper before rethrowing.
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
			try rethrowAfterRollback(
				error,
				steps: [
					{
						if fileManager.fileExists(atPath: helperURL.path) {
							try fileManager.removeItem(at: helperURL)
						}
					},
					{
						let restoreURL =
							fileManager.fileExists(atPath: previousURL.path)
							? previousURL : backupURL
						try fileManager.moveItem(at: restoreURL, to: helperURL)
					},
				]
			)
		}
	}

	// Every step runs even when an earlier one fails. Rollback failures are aggregated into
	// `GameShimRollbackError`; otherwise the operation error is rethrown unchanged.
	static func rethrowAfterRollback(
		_ operationError: Error,
		steps: [() throws -> Void]
	) throws -> Never {
		var rollbackErrors: [String] = []
		for step in steps {
			do {
				try step()
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

	// `backupURL` restores `destinationURL` if copying or moving the replacement fails.
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
			try rethrowAfterRollback(
				error,
				steps: [
					{
						if fileManager.fileExists(atPath: destinationURL.path) {
							try fileManager.removeItem(at: destinationURL)
						}
					},
					{
						if fileManager.fileExists(atPath: backupURL.path) {
							try fileManager.moveItem(at: backupURL, to: destinationURL)
						}
					},
				]
			)
		}
	}
}
