// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Shared low-level file operations behind `GameCompatibilityComponent` implementations.
/// Each component keeps its own install/restore orchestration, error messages, and recovery
/// rules; only the mechanical parts that are byte-for-byte identical across components live
/// here, so the two never drift out of sync on the same primitive.
enum GameShimIO {
	static func containsMarker(at url: URL, marker: Data, maximumSize: Int? = nil) throws -> Bool {
		let data = try Data(contentsOf: url, options: .mappedIfSafe)
		if let maximumSize, data.count > maximumSize { return false }
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

	/// Atomically swaps `helperURL` for `shimURL`, first backing up whatever is currently
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
			try? fileManager.removeItem(at: helperURL)
			if fileManager.fileExists(atPath: previousURL.path) {
				try? fileManager.moveItem(at: previousURL, to: helperURL)
			} else {
				try? fileManager.moveItem(at: backupURL, to: helperURL)
			}
			throw error
		}
	}

	/// Replaces `destinationURL` with `sourceURL`, moving any existing file at
	/// `destinationURL` to `backupURL` first so a failed copy can restore it.
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
			try? fileManager.removeItem(at: destinationURL)
			if fileManager.fileExists(atPath: backupURL.path) {
				try? fileManager.moveItem(at: backupURL, to: destinationURL)
			}
			throw error
		}
	}
}
