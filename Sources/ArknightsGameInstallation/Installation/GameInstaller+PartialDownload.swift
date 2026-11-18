// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Darwin
import Foundation

// Owns the partial file descriptor until `close()` or `closeAfterFailure(log:)`, so no path
// out of `GameInstaller.download` leaks it. Not `Sendable`: one attempt uses it serially.
final class PartialDownload {
	let item: ManifestFile
	let partial: InstallerFile
	let destination: InstallerFile
	let metadataFile: InstallerFile
	let descriptor: Int32
	let handle: FileHandle
	let counter: ProgressCounter
	let progress: GameInstaller.ProgressHandler
	// Bytes already in the `.part` file and counted in `counter` for this attempt.
	var existingBytes: Int64
	var resumeMetadata: InstallerResumeMetadata?
	private var isClosed = false

	// Every rollback names the bytes it discards, so the counter and the `.part` file agree.
	enum Rollback {
		case resumeStateMismatch(counted: Int64)
		case overlongPartial
		case restart(counted: Int64)
		case overflow(counted: Int64, network: Int64)
		case receivedRange(truncatingTo: UInt64, counted: Int64, synchronizes: Bool)
	}

	init(
		item: ManifestFile,
		partial: InstallerFile,
		destination: InstallerFile,
		metadataFile: InstallerFile,
		descriptor: Int32,
		existingBytes: Int64,
		counter: ProgressCounter,
		progress: @escaping GameInstaller.ProgressHandler
	) {
		self.item = item
		self.partial = partial
		self.destination = destination
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

	// The single rollback path. It takes the discarded bytes out of the shared counter.
	func discardBytes(_ rollback: Rollback) async throws {
		switch rollback {
		case .resumeStateMismatch(let counted):
			try await GameInstaller.rollBack(
				handle, of: item, truncatingTo: 0, counted: counted, network: 0,
				reportsProgress: counted > 0 && counted <= item.byteCount,
				rewinds: false, synchronizes: false, counter: counter, progress: progress)
		case .overlongPartial:
			try await GameInstaller.rollBack(
				handle, of: item, truncatingTo: 0, counted: 0, network: 0,
				reportsProgress: false, rewinds: false, synchronizes: false,
				counter: counter, progress: progress)
		case .restart(let counted):
			try await GameInstaller.rollBack(
				handle, of: item, truncatingTo: 0, counted: counted, network: 0,
				reportsProgress: true, rewinds: true, synchronizes: false,
				counter: counter, progress: progress)
		case .overflow(let counted, let network):
			try await GameInstaller.rollBack(
				handle, of: item, truncatingTo: 0, counted: counted, network: network,
				reportsProgress: true, rewinds: false, synchronizes: false,
				counter: counter, progress: progress)
		case .receivedRange(let truncatingTo, let counted, let synchronizes):
			try await GameInstaller.rollBack(
				handle, of: item, truncatingTo: truncatingTo, counted: counted,
				network: counted, reportsProgress: true, rewinds: false,
				synchronizes: synchronizes, counter: counter, progress: progress)
		}
	}
}

extension GameInstaller {
	// Every download rollback goes through here, including the checksum-mismatch rollback.
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
	// Validates the manifest path and destination, then opens the regular `.part` file without
	// following links.
	func openPartialDownload(
		_ item: ManifestFile,
		installDirectory: InstallerDirectory,
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
		let metadataFile = resumeMetadataFile(
			for: relativePath,
			in: try stagingDirectory(in: installDirectory)
		)
		let descriptor: Int32
		do {
			descriptor = try partial.open(
				flags: O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC,
				mode: S_IRUSR | S_IWUSR
			)
		} catch {
			throw mapInstallerFileSystemError(error)
		}
		let existingBytes: Int64
		do {
			existingBytes = try PartialDownloadFile.validatedSize(of: descriptor, at: partial.url)
		} catch PartialDownloadFileError.unsafeFile(let url) {
			throw InstallerError.unsafeInstallerTemporaryFile(url)
		}
		return PartialDownload(
			item: item,
			partial: partial,
			destination: destination,
			metadataFile: metadataFile,
			descriptor: descriptor,
			existingBytes: existingBytes,
			counter: counter,
			progress: progress
		)
	}

	// Drops resume state that no longer matches the manifest, so only trustworthy bytes
	// count as already downloaded.
	func reconcileResumeState(of download: PartialDownload) async throws {
		let item = download.item
		download.resumeMetadata = try readResumeMetadata(at: download.metadataFile)
		if let priorMetadata = download.resumeMetadata,
			!ManifestChecksum.matches(priorMetadata.manifestHash, expected: item.hash)
		{
			let existingBytes = download.existingBytes
			try await download.discardBytes(.resumeStateMismatch(counted: existingBytes))
			download.existingBytes = 0
			try download.metadataFile.unlink()
			download.resumeMetadata = nil
		}
		if download.existingBytes > item.byteCount {
			try await download.discardBytes(.overlongPartial)
			download.existingBytes = 0
		}
	}

	// Builds the ranged request, checking the source against the region's download policy.
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
