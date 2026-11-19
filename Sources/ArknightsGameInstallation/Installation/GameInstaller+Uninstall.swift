// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Darwin
import Foundation

/// How much of the install folder an uninstall may remove.
package enum UninstallScope: Sendable {
	/// The launcher owns the whole folder, so all of it goes to the Trash.
	case wholeFolder
	/// The folder may hold the user's files, so only what the launcher installed goes.
	case installedFilesOnly
}

package enum UninstallOutcome: Sendable, Equatable {
	case removed
	/// No installed-file list exists, so only the launcher's own working files were removed.
	case installedFilesUnknown
}

extension GameInstaller {
	@concurrent
	package func uninstall(
		from installDirectory: URL,
		scope: UninstallScope
	) async throws -> UninstallOutcome {
		// Only lease acquisition gets the lease mapping; body errors keep their own type.
		var leaseAcquired = false
		do {
			return try withInstallLease(at: installDirectory) { lease -> UninstallOutcome in
				leaseAcquired = true
				switch scope {
				case .wholeFolder:
					try FileManager.default.trashItem(
						at: lease.directory.url, resultingItemURL: nil)
					return .removed
				case .installedFilesOnly:
					return try removeInstalledFiles(in: lease.directory)
				}
			}
		} catch {
			throw leaseAcquired ? error : mapInstallerFileSystemError(error)
		}
	}

	/// Moves the files listed in the installed state into one Trash folder, deletes the launcher's
	/// working files, and prunes folders that became empty. Anything else stays.
	private func removeInstalledFiles(in root: InstallerDirectory) throws -> UninstallOutcome {
		bestEffort("Could not restore compatibility files before uninstalling") {
			try compatibilityManager.restoreForUpdate(in: root.url)
		}
		let manifestFiles = installedManifestFiles(in: root)
		let listed = (manifestFiles ?? []).compactMap { resolveManifestFile($0.path, in: root) }
		var touchedDirectories = Set<String>()

		try trashFiles(listed, in: root, touched: &touchedDirectories)
		removeInstallerWorkingFiles(in: root)
		// Without a file list a `.part` file cannot be told apart from the user's own, so it stays.
		if manifestFiles != nil {
			for entry in listed {
				removeRegularFile(at: entry.file.sibling(named: entry.file.name + ".part").url)
				note(entry.file.url, in: root, touched: &touchedDirectories)
			}
		}
		for path in touchedDirectories.sorted(by: { $0.count > $1.count }) {
			removeDirectoryIfEmpty(URL(fileURLWithPath: path, isDirectory: true))
		}
		removeDirectoryIfEmpty(root.url)

		let folderRemains = FileManager.default.fileExists(atPath: root.url.path)
		return manifestFiles == nil && folderRemains ? .installedFilesUnknown : .removed
	}

	// `log?.attempt` would skip the work itself when there is no logger.
	private func bestEffort(_ context: String, _ work: () throws -> Void) {
		GameShimIO.attempt(context, log: log, work)
	}

	private func installedManifestFiles(in root: InstallerDirectory) -> [ManifestFile]? {
		do {
			return try loadState(from: root)?.files
		} catch {
			log?.error(
				"Could not read the installed state for uninstall: \(launcherDiagnosticDescription(for: error))"
			)
			return nil
		}
	}

	/// Applies the installer's manifest path rules. A path that fails them is left alone.
	private func resolveManifestFile(
		_ path: String,
		in root: InstallerDirectory
	) -> (relativePath: String, file: InstallerFile)? {
		do {
			let relativePath = try Self.safeRelativePath(path)
			return (relativePath, try root.file(at: relativePath))
		} catch {
			log?.error(
				"Left a listed file that failed path validation: \(launcherDiagnosticDescription(for: error))"
			)
			return nil
		}
	}

	// Rename keeps this cheap on one volume, and one folder in the Trash stays restorable where
	// thousands of separate items would not. Any failure moves the files back.
	private func trashFiles(
		_ listed: [(relativePath: String, file: InstallerFile)],
		in root: InstallerDirectory,
		touched: inout Set<String>
	) throws {
		var stage: InstallerDirectory?
		var moved: [(staged: InstallerFile, original: InstallerFile)] = []
		do {
			for (relativePath, original) in listed where isRegularFile(original) {
				let current = try stage ?? makeTrashStage(in: root)
				stage = current
				let destination = try current.file(at: relativePath, createParents: true)
				try original.rename(to: destination)
				moved.append((destination, original))
			}
			if let stage {
				try FileManager.default.trashItem(at: stage.url, resultingItemURL: nil)
			}
		} catch {
			restore(moved, stage: stage)
			throw error
		}
		for entry in moved { note(entry.original.url, in: root, touched: &touched) }
	}

	private func makeTrashStage(in root: InstallerDirectory) throws -> InstallerDirectory {
		var name = "Arknights Game Files"
		let taken: Bool
		do {
			taken = try root.file(named: name).stat() != nil
		} catch {
			taken = true
		}
		if taken { name += " \(UUID().uuidString)" }
		return try root.stagingDirectory(named: name)
	}

	private func restore(
		_ moved: [(staged: InstallerFile, original: InstallerFile)],
		stage: InstallerDirectory?
	) {
		var restoredAll = true
		for entry in moved.reversed() {
			do {
				try entry.staged.rename(to: entry.original)
			} catch {
				restoredAll = false
				log?.error(
					"Could not put back \(entry.original.url.path): \(launcherDiagnosticDescription(for: error))"
				)
			}
		}
		// Only empty folders remain when every file came back.
		guard restoredAll, let stage else { return }
		bestEffort("Could not remove the empty uninstall folder") {
			try FileManager.default.removeItem(at: stage.url)
		}
	}

	private func isRegularFile(_ file: InstallerFile) -> Bool {
		do {
			guard let attributes = try file.stat() else { return false }
			return attributes.st_mode & S_IFMT == S_IFREG
		} catch {
			log?.error(
				"Left \(file.url.path): \(launcherDiagnosticDescription(for: error))"
			)
			return false
		}
	}

	private func removeInstallerWorkingFiles(in root: InstallerDirectory) {
		let state = root.file(named: AppConstants.Game.installedStateFileName)
		bestEffort("Could not remove the installed state") { try state.unlink() }
		let staging = root.file(named: AppConstants.Game.installerStagingDirectoryName)
		bestEffort("Could not remove the installer working folder") {
			if let attributes = try staging.stat(), attributes.st_mode & S_IFMT == S_IFDIR {
				try FileManager.default.removeItem(at: staging.url)
			}
		}
	}

	/// Unlinks a regular file and never follows a link, so a symbolic link is left as it is.
	private func removeRegularFile(at url: URL) {
		bestEffort("Could not remove \(url.path)") {
			var attributes = stat()
			guard lstat(url.path, &attributes) == 0 else {
				if errno == ENOENT { return }
				throw POSIXError(.init(rawValue: errno) ?? .EIO)
			}
			guard attributes.st_mode & S_IFMT == S_IFREG else { return }
			guard Darwin.unlink(url.path) == 0 || errno == ENOENT else {
				throw POSIXError(.init(rawValue: errno) ?? .EIO)
			}
		}
	}

	private func note(_ url: URL, in root: InstallerDirectory, touched: inout Set<String>) {
		var directory = url.deletingLastPathComponent()
		while directory.path.hasPrefix(root.url.path + "/") {
			touched.insert(directory.path)
			directory = directory.deletingLastPathComponent()
		}
	}

	private func removeDirectoryIfEmpty(_ directory: URL) {
		bestEffort("Could not prune \(directory.path)") {
			// Finder's `.DS_Store` must not keep an otherwise empty folder alive.
			let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
			if names == [".DS_Store"] {
				removeRegularFile(at: directory.appending(path: ".DS_Store"))
			}
			guard Darwin.rmdir(directory.path) == 0 else {
				let code = errno
				if code == ENOTEMPTY || code == EEXIST || code == ENOENT { return }
				throw POSIXError(.init(rawValue: code) ?? .EIO)
			}
		}
	}
}
