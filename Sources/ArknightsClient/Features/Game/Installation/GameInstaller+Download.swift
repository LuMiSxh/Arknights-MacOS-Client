// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

/// One manifest file from request to installed byte: retrying across CDNs, then verifying
/// a private staged inode before atomic promotion.
extension GameInstaller {
	func addDownload(
		_ item: ManifestFile,
		manifest: GameManifest,
		cdn: CDNConfiguration,
		installDirectory: InstallerInstallDirectory,
		counter: ProgressCounter,
		progress: @escaping ProgressHandler,
		region: GameRegion,
		to group: inout ThrowingTaskGroup<Int64, any Error>
	) {
		group.addTask {
			try await downloadWithRetry(
				item,
				source: manifest.source,
				cdn: cdn,
				installDirectory: installDirectory,
				counter: counter,
				progress: progress,
				region: region
			)
		}
	}

	private func downloadWithRetry(
		_ item: ManifestFile,
		source: String,
		cdn: CDNConfiguration,
		installDirectory: InstallerInstallDirectory,
		counter: ProgressCounter,
		progress: @escaping ProgressHandler,
		region: GameRegion
	) async throws -> Int64 {
		let maxAttempts = AppConstants.Network.maxDownloadAttempts
		for attempt in 1...maxAttempts {
			do {
				return try await download(
					item,
					source: source,
					baseURL: attempt == 1 ? cdn.primaryCdn : cdn.backUpCdn,
					installDirectory: installDirectory,
					counter: counter,
					progress: progress,
					region: region
				)
			} catch is CancellationError {
				throw CancellationError()
			} catch {
				if attempt == maxAttempts { throw error }
				await progress(await counter.resetRate(file: item.path))
				log?.debug(
					"Retrying \(item.path) (attempt \(attempt + 1)/\(maxAttempts)) after: "
						+ launcherDiagnosticDescription(for: error)
				)
				try await Task.sleep(for: AppConstants.Network.retryBackoffStep * attempt)
			}
		}
		throw LauncherError.invalidResponse
	}

	func finishDownload(
		_ item: ManifestFile,
		partial: InstallerFilePath,
		partialDescriptor: Int32,
		destination: InstallerFilePath,
		stagingDirectory: InstallerDirectoryHandle,
		metadataFile: InstallerFilePath,
		countedBytes: Int64,
		networkBytes: Int64,
		counter: ProgressCounter,
		progress: @escaping ProgressHandler
	) async throws {
		var sourceStatus = stat()
		guard fstat(partialDescriptor, &sourceStatus) == 0,
			sourceStatus.st_mode & S_IFMT == S_IFREG,
			sourceStatus.st_nlink == 0 || sourceStatus.st_nlink == 1
		else {
			throw LauncherError.unsafeInstallerTemporaryFile(partial.url)
		}
		let actualSize = Int64(sourceStatus.st_size)
		guard actualSize == item.byteCount else {
			throw LauncherError.downloadedSizeMismatch(
				path: item.path,
				expected: item.byteCount,
				actual: actualSize
			)
		}

		let publicationDirectory = try stagingDirectoryForPromotion(
			sourceStatus: sourceStatus,
			destination: destination,
			rootStagingDirectory: stagingDirectory
		)
		let staged = publicationDirectory.file(named: "payload-\(UUID().uuidString).tmp")
		var stagedIdentity: InstallerFileIdentity?
		var didPromote = false
		defer {
			if !didPromote {
				do {
					if let status = try staged.stat(),
						stagedIdentity == nil || InstallerFileIdentity(status) == stagedIdentity
					{
						try staged.unlink()
					}
				} catch {
					log?.error(
						"Failed to remove private staged file for \(item.path): \(error.localizedDescription)"
					)
				}
			}
		}

		try cloneOrCopy(
			from: partialDescriptor,
			to: staged,
			expectedSize: item.byteCount,
			sourceURL: partial.url
		)
		let stagedDescriptor = try staged.open(flags: O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
		defer { _ = close(stagedDescriptor) }
		try InstallerInstallDirectory.makePrivateRegularFile(
			stagedDescriptor,
			at: staged.url
		)
		var beforeHash = stat()
		guard fstat(stagedDescriptor, &beforeHash) == 0,
			beforeHash.st_mode & S_IFMT == S_IFREG,
			beforeHash.st_nlink == 1,
			beforeHash.st_size == item.byteCount
		else { throw LauncherError.unsafeInstallerTemporaryFile(staged.url) }
		stagedIdentity = InstallerFileIdentity(beforeHash)
		let checksum = try ManifestChecksum.checksum(
			ofFileDescriptor: stagedDescriptor,
			expected: item.hash
		)
		var afterHash = stat()
		guard fstat(stagedDescriptor, &afterHash) == 0,
			InstallerFileIdentity(afterHash) == stagedIdentity,
			afterHash.st_size == beforeHash.st_size,
			let stagedNameStatus = try staged.stat(),
			InstallerFileIdentity(stagedNameStatus) == stagedIdentity
		else { throw LauncherError.unsafeInstallerTemporaryFile(staged.url) }
		guard ManifestChecksum.matches(checksum, expected: item.hash) else {
			guard ftruncate(partialDescriptor, 0) == 0 else {
				throw POSIXError(.init(rawValue: errno) ?? .EIO)
			}
			guard fsync(partialDescriptor) == 0 else {
				throw POSIXError(.init(rawValue: errno) ?? .EIO)
			}
			await progress(
				await counter.remove(
					bytes: countedBytes,
					networkBytes: networkBytes,
					file: item.path
				)
			)
			throw LauncherError.checksumMismatch(
				path: item.path,
				expected: item.hash,
				actual: checksum
			)
		}

		try Task.checkCancellation()
		try staged.rename(to: destination)
		didPromote = true
		guard fsync(publicationDirectory.descriptor) == 0,
			fsync(destination.directory.descriptor) == 0
		else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
		guard let installedStatus = try destination.stat(),
			InstallerFileIdentity(installedStatus) == stagedIdentity,
			installedStatus.st_size == item.byteCount
		else { throw LauncherError.unsafeInstallerTemporaryFile(destination.url) }

		do {
			try retirePartial(
				partial,
				descriptor: partialDescriptor,
				in: publicationDirectory
			)
		} catch {
			log?.error(
				"Could not retire verified partial file at \(partial.url.path): \(error.localizedDescription)"
			)
		}
		do {
			try metadataFile.unlink()
		} catch {
			log?.error(
				"Could not remove resume metadata for \(item.path): \(error.localizedDescription)"
			)
		}
	}

	private func stagingDirectoryForPromotion(
		sourceStatus: stat,
		destination: InstallerFilePath,
		rootStagingDirectory: InstallerDirectoryHandle
	) throws -> InstallerDirectoryHandle {
		var rootStatus = stat()
		var destinationStatus = stat()
		guard fstat(rootStagingDirectory.descriptor, &rootStatus) == 0,
			fstat(destination.directory.descriptor, &destinationStatus) == 0,
			sourceStatus.st_dev == destinationStatus.st_dev
		else { throw LauncherError.unsafeInstallerTemporaryFile(destination.url) }
		if sourceStatus.st_dev == rootStatus.st_dev { return rootStagingDirectory }
		return try destination.directory.stagingDirectory(
			named: AppConstants.Game.installerStagingDirectoryName
		)
	}

	private func cloneOrCopy(
		from sourceDescriptor: Int32,
		to destination: InstallerFilePath,
		expectedSize: Int64,
		sourceURL: URL
	) throws {
		if fclonefileat(sourceDescriptor, destination.directory.descriptor, destination.name, 0)
			== 0
		{
			return
		}
		let cloneError = errno
		guard
			cloneError == ENOTSUP || cloneError == EOPNOTSUPP || cloneError == EXDEV
				|| cloneError == EINVAL || cloneError == ENOSYS
		else { throw POSIXError(.init(rawValue: cloneError) ?? .EIO) }
		try copyFileDescriptor(
			sourceDescriptor,
			to: destination,
			expectedSize: expectedSize,
			sourceURL: sourceURL
		)
	}

	private func copyFileDescriptor(
		_ source: Int32,
		to destination: InstallerFilePath,
		expectedSize: Int64,
		sourceURL: URL
	) throws {
		var initialStatus = stat()
		guard fstat(source, &initialStatus) == 0,
			initialStatus.st_mode & S_IFMT == S_IFREG,
			initialStatus.st_size == expectedSize
		else { throw LauncherError.unsafeInstallerTemporaryFile(sourceURL) }
		let output = try destination.open(
			flags: O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
			mode: S_IRUSR | S_IWUSR
		)
		var keepOutput = false
		defer {
			_ = close(output)
			if !keepOutput {
				do {
					try destination.unlink()
				} catch {
					log?.error(
						"Failed to clean incomplete staged copy at \(destination.url.path): \(error.localizedDescription)"
					)
				}
			}
		}
		var offset: off_t = 0
		var buffer = [UInt8](repeating: 0, count: AppConstants.IO.checksumBufferSize)
		while offset < expectedSize {
			try Task.checkCancellation()
			let requested = min(buffer.count, Int(expectedSize - Int64(offset)))
			let count = buffer.withUnsafeMutableBytes { bytes in
				pread(source, bytes.baseAddress, requested, offset)
			}
			if count < 0 {
				if errno == EINTR { continue }
				throw POSIXError(.init(rawValue: errno) ?? .EIO)
			}
			guard count > 0 else { throw POSIXError(.EIO) }
			try buffer.withUnsafeBytes { bytes in
				guard let baseAddress = bytes.baseAddress else { return }
				var written = 0
				while written < count {
					let result = Darwin.write(
						output,
						baseAddress.advanced(by: written),
						count - written
					)
					if result < 0 {
						if errno == EINTR { continue }
						throw POSIXError(.init(rawValue: errno) ?? .EIO)
					}
					guard result > 0 else { throw POSIXError(.EIO) }
					written += result
				}
			}
			offset += off_t(count)
		}
		var finalStatus = stat()
		guard fstat(source, &finalStatus) == 0,
			InstallerFileIdentity(finalStatus) == InstallerFileIdentity(initialStatus),
			finalStatus.st_size == initialStatus.st_size,
			finalStatus.st_mtimespec.tv_sec == initialStatus.st_mtimespec.tv_sec,
			finalStatus.st_mtimespec.tv_nsec == initialStatus.st_mtimespec.tv_nsec,
			finalStatus.st_ctimespec.tv_sec == initialStatus.st_ctimespec.tv_sec,
			finalStatus.st_ctimespec.tv_nsec == initialStatus.st_ctimespec.tv_nsec
		else { throw LauncherError.unsafeInstallerTemporaryFile(sourceURL) }
		guard fsync(output) == 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		keepOutput = true
	}

	private func retirePartial(
		_ partial: InstallerFilePath,
		descriptor: Int32,
		in privateDirectory: InstallerDirectoryHandle
	) throws {
		var expectedStatus = stat()
		guard fstat(descriptor, &expectedStatus) == 0 else {
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		let expectedIdentity = InstallerFileIdentity(expectedStatus)
		guard let namedStatus = try partial.stat(),
			InstallerFileIdentity(namedStatus) == expectedIdentity
		else { return }
		let retired = privateDirectory.file(named: "retired-\(UUID().uuidString).tmp")
		try partial.rename(to: retired)
		guard let retiredStatus = try retired.stat() else { return }
		guard InstallerFileIdentity(retiredStatus) == expectedIdentity else {
			do {
				try retired.renameExclusively(to: partial)
			} catch {
				log?.error(
					"Left a substituted partial in private staging for manual cleanup at \(retired.url.path): \(error.localizedDescription)"
				)
			}
			return
		}
		try retired.unlink()
	}
}
