// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

/// The validated `.part` file and resume bookkeeping of one download attempt.
///
/// Owns the partial file descriptor until `close()` or `closeAfterFailure(log:)`, so no path
/// out of `GameInstaller.download` leaks it. Not `Sendable`: one attempt uses it serially.
final class PartialDownload {
	let item: ManifestFile
	let partial: InstallerFilePath
	let destination: InstallerFilePath
	let stagingDirectory: InstallerDirectoryHandle
	let metadataFile: InstallerFilePath
	let descriptor: Int32
	let handle: FileHandle
	let counter: ProgressCounter
	let progress: GameInstaller.ProgressHandler
	/// Bytes already in the `.part` file and counted in `counter` for this attempt.
	var existingBytes: Int64
	var resumeMetadata: InstallerResumeMetadata?
	private var isClosed = false

	init(
		item: ManifestFile,
		partial: InstallerFilePath,
		destination: InstallerFilePath,
		stagingDirectory: InstallerDirectoryHandle,
		metadataFile: InstallerFilePath,
		descriptor: Int32,
		existingBytes: Int64,
		counter: ProgressCounter,
		progress: @escaping GameInstaller.ProgressHandler
	) {
		self.item = item
		self.partial = partial
		self.destination = destination
		self.stagingDirectory = stagingDirectory
		self.metadataFile = metadataFile
		self.descriptor = descriptor
		handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
		self.existingBytes = existingBytes
		self.counter = counter
		self.progress = progress
	}

	func close() throws {
		try handle.close()
		isClosed = true
	}

	func closeAfterFailure(log: LauncherLog?) {
		guard !isClosed else { return }
		do {
			try handle.close()
		} catch {
			log?.error(
				"Failed to close partial download at \(partial.url.path): \(error.localizedDescription)"
			)
		}
	}

	/// The single rollback path: truncates the partial to `offset` and takes the discarded
	/// bytes back out of the shared progress counter.
	///
	/// - Parameters:
	///   - offset: Length the partial keeps. Resume rollbacks keep the resume offset.
	///   - counted: Bytes to remove from the counter's downloaded total.
	///   - network: Bytes to remove from the counter's network total.
	///   - reportsProgress: `false` when the counter never included the discarded bytes.
	///   - rewinds: Moves the write position to `offset` so the stream can keep writing.
	///   - synchronizes: Flushes the truncation before progress is reported.
	func discardBytes(
		truncatingTo offset: UInt64 = 0,
		counted: Int64 = 0,
		network: Int64 = 0,
		reportsProgress: Bool = true,
		rewinds: Bool = false,
		synchronizes: Bool = false
	) async throws {
		try await GameInstaller.rollBack(
			handle,
			of: item,
			truncatingTo: offset,
			counted: counted,
			network: network,
			reportsProgress: reportsProgress,
			rewinds: rewinds,
			synchronizes: synchronizes,
			counter: counter,
			progress: progress
		)
	}
}

extension GameInstaller {
	/// Truncates a partial and removes the discarded bytes from the progress counter. Every
	/// download rollback goes through here, including the checksum-mismatch rollback.
	static func rollBack(
		_ handle: FileHandle,
		of item: ManifestFile,
		truncatingTo offset: UInt64,
		counted: Int64,
		network: Int64,
		reportsProgress: Bool,
		rewinds: Bool,
		synchronizes: Bool,
		counter: ProgressCounter,
		progress: ProgressHandler
	) async throws {
		try handle.truncate(atOffset: offset)
		if rewinds { try handle.seek(toOffset: offset) }
		if synchronizes { try handle.synchronize() }
		guard reportsProgress else { return }
		await progress(await counter.remove(bytes: counted, networkBytes: network, file: item.path))
	}
}

extension GameInstaller {
	/// Validates the manifest path and destination, then opens the private regular `.part`
	/// file without following links.
	func openPartialDownload(
		_ item: ManifestFile,
		installDirectory: InstallerInstallDirectory,
		counter: ProgressCounter,
		progress: @escaping ProgressHandler
	) throws -> PartialDownload {
		let relativePath = try Self.safeRelativePath(item.path)
		let destination = try installFile(
			at: relativePath,
			inside: installDirectory,
			createParents: true
		)
		let partial = destination.sibling(named: destination.name + ".part")
		try assertRegularDestinationIfPresent(destination)
		try assertSafeExistingPartialFile(at: partial)
		let stagingDirectory: InstallerDirectoryHandle
		do {
			stagingDirectory = try installDirectory.stagingDirectory(
				named: AppConstants.Game.installerStagingDirectoryName
			)
		} catch {
			throw mapInstallerFileSystemError(error)
		}
		let metadataFile = resumeMetadataFile(for: relativePath, in: stagingDirectory)
		let descriptor: Int32
		do {
			descriptor = try partial.open(
				flags: O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC,
				mode: S_IRUSR | S_IWUSR
			)
		} catch {
			throw mapInstallerFileSystemError(error)
		}
		var fileStatus = stat()
		guard fstat(descriptor, &fileStatus) == 0,
			fileStatus.st_mode & S_IFMT == S_IFREG,
			fileStatus.st_nlink == 1,
			fileStatus.st_size >= 0
		else {
			_ = close(descriptor)
			throw LauncherError.unsafeInstallerTemporaryFile(partial.url)
		}
		return PartialDownload(
			item: item,
			partial: partial,
			destination: destination,
			stagingDirectory: stagingDirectory,
			metadataFile: metadataFile,
			descriptor: descriptor,
			existingBytes: Int64(fileStatus.st_size),
			counter: counter,
			progress: progress
		)
	}

	/// Drops resume state that no longer matches the manifest, so only trustworthy bytes
	/// count as already downloaded.
	func reconcileResumeState(of download: PartialDownload) async throws {
		let item = download.item
		download.resumeMetadata = try readResumeMetadata(at: download.metadataFile)
		if let priorMetadata = download.resumeMetadata,
			!ManifestChecksum.matches(priorMetadata.manifestHash, expected: item.hash)
		{
			let existingBytes = download.existingBytes
			try await download.discardBytes(
				counted: existingBytes,
				reportsProgress: existingBytes <= item.byteCount && existingBytes > 0
			)
			download.existingBytes = 0
			try download.metadataFile.unlink()
			download.resumeMetadata = nil
		}
		if download.existingBytes > item.byteCount {
			try await download.discardBytes(reportsProgress: false)
			download.existingBytes = 0
		}
	}

	/// Builds the ranged request, checking the source against the region's download policy.
	func resumeRequest(
		for download: PartialDownload,
		source: String,
		baseURL: URL,
		region: GameRegion
	) throws -> URLRequest {
		let relativeSource = try Self.safeRelativePath(source)
		let relativeFile = try Self.safeRelativePath(download.item.path)
		let downloadURL =
			baseURL
			.appending(path: relativeSource, directoryHint: .isDirectory)
			.appending(path: relativeFile)
		guard DownloadHTTPPolicy.isAllowedSource(downloadURL, for: region) else {
			throw LauncherError.invalidResponse
		}
		var request = URLRequest(url: downloadURL)
		if download.existingBytes > 0 {
			request.setValue("bytes=\(download.existingBytes)-", forHTTPHeaderField: "Range")
			if let ifRange = download.resumeMetadata?.ifRangeValue {
				request.setValue(ifRange, forHTTPHeaderField: "If-Range")
			}
		}
		return request
	}
}
