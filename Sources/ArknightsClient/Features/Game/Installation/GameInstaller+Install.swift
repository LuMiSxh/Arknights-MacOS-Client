// SPDX-License-Identifier: MPL-2.0

import Foundation

extension GameInstaller {
	func install(
		configuration: GameConfiguration,
		region: GameRegion,
		into installDirectory: URL,
		verifyAllExistingFiles: Bool = false,
		progress: @escaping ProgressHandler
	) async throws -> InstallResult {
		// Only lease acquisition gets the lease mapping; body errors keep their per-step mapping.
		var leaseAcquired = false
		do {
			return try await withInstallLease(at: installDirectory) { lease in
				leaseAcquired = true
				return try await installHoldingLease(
					configuration: configuration,
					region: region,
					into: installDirectory,
					installationRoot: lease.directory,
					verifyAllExistingFiles: verifyAllExistingFiles,
					progress: progress
				)
			}
		} catch {
			throw leaseAcquired ? error : mapInstallerFileSystemError(error)
		}
	}

	/// Runs the install while the caller holds the install lease on `installationRoot`.
	private func installHoldingLease(
		configuration: GameConfiguration,
		region: GameRegion,
		into installDirectory: URL,
		installationRoot: InstallerInstallDirectory,
		verifyAllExistingFiles: Bool,
		progress: @escaping ProgressHandler
	) async throws -> InstallResult {
		let (manifest, cdn) = try await Self.fetchRemoteResources {
			try await (
				api.manifest(for: configuration, region: region),
				api.cdnConfiguration(region: region)
			)
		}
		do {
			try validateManifest(manifest, in: installationRoot)
		} catch {
			throw mapInstallerFileSystemError(error)
		}
		do {
			try excludeFromBackup(installationRoot.url)
		} catch {
			log?.error(
				"Failed to exclude game installation from backups at \(installationRoot.url.path): \(error.localizedDescription)"
			)
		}
		try compatibilityManager.restoreForUpdate(in: installationRoot.url)
		let previousState: InstalledState?
		do {
			previousState = try loadState(from: installationRoot)
		} catch {
			previousState = nil
			log?.error(
				"Failed to read installed-state file at \(installationRoot.url.path): \(error.localizedDescription)"
			)
		}
		let previousFiles = previousState?.files.map {
			Dictionary($0.map { ($0.path, $0) }, uniquingKeysWith: { existing, _ in existing })
		}
		let verification = try await pendingDownloads(
			in: manifest,
			installDirectory: installationRoot,
			previousFiles: previousFiles,
			verifyAllExistingFiles: verifyAllExistingFiles,
			progress: progress
		)
		let pendingFiles = verification.files
		let downloadedBytes = try Self.totalByteCount(of: pendingFiles)
		log?.debug(
			"Manifest has \(manifest.file.count) files; \(pendingFiles.count) need download "
				+ "(\(downloadedBytes) bytes); repair=\(verifyAllExistingFiles)"
		)
		let progressBaseline = try DownloadProgressBaseline(
			manifestFiles: manifest.file,
			pendingFiles: pendingFiles,
			isIncompleteInstallation: previousFiles == nil
		) { item in
			let relativePath = try Self.safeRelativePath(item.path)
			let destination = try installFile(at: relativePath, inside: installationRoot)
			let partial = destination.sibling(named: destination.name + ".part")
			return try fileSize(at: partial) ?? 0
		}
		let counter = ProgressCounter(
			totalBytes: progressBaseline.totalBytes,
			totalFiles: progressBaseline.totalFiles,
			downloadedBytes: progressBaseline.downloadedBytes,
			completedFiles: progressBaseline.completedFiles,
			sequence: verification.lastSequence
		)
		if pendingFiles.isEmpty {
			try Task.checkCancellation()
			try saveState(configuration: configuration, manifest: manifest, to: installationRoot)
			return InstallResult(
				downloadedFiles: 0, downloadedBytes: 0, installDirectory: installDirectory)
		}
		await progress(await counter.current(file: pendingFiles[0].path))
		let reuse = await reuseSession(for: region, target: installationRoot)
		try Task.checkCancellation()
		try await withThrowingTaskGroup(of: Int64.self) { group in
			var nextIndex = 0
			let initialCount = min(concurrentDownloads, pendingFiles.count)
			for _ in 0..<initialCount {
				let item = pendingFiles[nextIndex]
				nextIndex += 1
				addDownload(
					item,
					manifest: manifest,
					cdn: cdn,
					installDirectory: installationRoot,
					counter: counter,
					progress: progress,
					region: region,
					reuse: reuse,
					to: &group
				)
			}

			do {
				while try await group.next() != nil {
					if nextIndex < pendingFiles.count {
						let item = pendingFiles[nextIndex]
						nextIndex += 1
						addDownload(
							item,
							manifest: manifest,
							cdn: cdn,
							installDirectory: installationRoot,
							counter: counter,
							progress: progress,
							region: region,
							reuse: reuse,
							to: &group
						)
					}
				}
			} catch {
				group.cancelAll()
				throw error
			}
		}

		try Task.checkCancellation()
		try saveState(configuration: configuration, manifest: manifest, to: installationRoot)
		let reusedFiles = await reuse.tally.files
		let reusedBytes = await reuse.tally.bytes
		log?.debug(
			"Install finished; \(pendingFiles.count) file(s), \(downloadedBytes) bytes; "
				+ "reused \(reusedFiles) file(s), \(reusedBytes) bytes from other regions"
		)
		return InstallResult(
			downloadedFiles: pendingFiles.count,
			downloadedBytes: downloadedBytes,
			installDirectory: installDirectory
		)
	}
}
