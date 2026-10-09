// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

/// Installs or repairs a region from its manifest, resuming partial downloads and reusing
/// unchanged files by checksum.
struct GameInstaller: Sendable {
	typealias ProgressHandler = @Sendable (DownloadProgress) async -> Void

	let api: any LauncherAPIProviding
	let chunkSession: HTTPChunkSession
	let compatibilityManager: GameCompatibilityManager
	let concurrentDownloads = AppConstants.Network.concurrentDownloads
	let log: LauncherLog?
	/// Directories of other regions' installations, resolved per operation so custom
	/// install locations are honored. `nil` disables cross-region reuse.
	let reuseSourceDirectories: (@Sendable (GameRegion) async -> [URL])?

	var fileManager: FileManager { .default }

	init(
		api: any LauncherAPIProviding,
		session: URLSession = .shared,
		compatibilityManager: GameCompatibilityManager,
		log: LauncherLog? = nil,
		reuseSourceDirectories: (@Sendable (GameRegion) async -> [URL])? = nil
	) {
		self.api = api
		chunkSession = HTTPChunkSession(configuration: session.configuration)
		self.compatibilityManager = compatibilityManager
		self.log = log
		self.reuseSourceDirectories = reuseSourceDirectories
	}

	/// Downloads one manifest file and promotes it, returning the bytes fetched from the
	/// network. Every failure leaves the `.part` file either resumable or truncated to
	/// match the progress that was rolled back.
	func download(
		_ item: ManifestFile,
		source: String,
		baseURL: URL,
		installDirectory: InstallerInstallDirectory,
		counter: ProgressCounter,
		progress: @escaping ProgressHandler,
		region: GameRegion = .global
	) async throws -> Int64 {
		try Task.checkCancellation()
		let download = try openPartialDownload(
			item,
			installDirectory: installDirectory,
			counter: counter,
			progress: progress
		)
		defer { download.closeAfterFailure(log: log) }
		try await reconcileResumeState(of: download)

		if download.existingBytes == item.byteCount {
			try Task.checkCancellation()
			try await promote(download, networkBytes: 0)
			return 0
		}

		let request = try resumeRequest(
			for: download,
			source: source,
			baseURL: baseURL,
			region: region
		)
		try download.handle.seekToEnd()
		let networkBytes = try await receive(
			request,
			redirectValidator: DownloadHTTPPolicy.redirectValidator(for: region),
			into: download
		)
		try download.handle.synchronize()
		try Task.checkCancellation()
		try await promote(download, networkBytes: networkBytes)
		return networkBytes
	}

	/// Verifies and publishes the completed partial, then closes it and counts the file.
	private func promote(_ download: PartialDownload, networkBytes: Int64) async throws {
		try await finishDownload(
			download.item,
			partial: download.partial,
			partialDescriptor: download.descriptor,
			destination: download.destination,
			stagingDirectory: download.stagingDirectory,
			metadataFile: download.metadataFile,
			countedBytes: download.existingBytes + networkBytes,
			networkBytes: networkBytes,
			counter: download.counter,
			progress: download.progress
		)
		try download.close()
		if let update = await download.counter.add(
			bytes: 0,
			file: download.item.path,
			force: true
		) {
			await download.progress(update)
		}
	}
}
