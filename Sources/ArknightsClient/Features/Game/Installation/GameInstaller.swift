// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

/// Installs or repairs a region from its manifest, resuming partial downloads and reusing
/// unchanged files by checksum.
struct GameInstaller: Sendable {
	typealias ProgressHandler = @Sendable (DownloadProgress) async -> Void

	let api: any LauncherAPIProviding
	private let chunkSession: HTTPChunkSession
	let compatibilityManager: GameCompatibilityManager
	let concurrentDownloads = AppConstants.Network.concurrentDownloads
	private static let gryphlineDownloadHosts: Set<String> = [
		"ak-tw.hg-cdn.com",
		"launcher.hg-cdn.com",
		"gl-utils-public.hg-cdn.com",
	]
	let log: LauncherLog?

	var fileManager: FileManager { .default }

	init(
		api: any LauncherAPIProviding,
		session: URLSession = .shared,
		compatibilityManager: GameCompatibilityManager,
		log: LauncherLog? = nil
	) {
		self.api = api
		chunkSession = HTTPChunkSession(configuration: session.configuration)
		self.compatibilityManager = compatibilityManager
		self.log = log
	}

	static func downloadRedirectValidator(
		for region: GameRegion
	) -> (@Sendable (URL) -> Bool)? {
		guard region == .taiwan else { return nil }
		return { url in
			guard url.scheme?.lowercased() == "https",
				url.user == nil,
				url.password == nil,
				url.port == nil,
				let host = url.host?.lowercased()
			else { return false }
			return Self.gryphlineDownloadHosts.contains(host)
		}
	}

	func download(
		_ item: ManifestFile,
		source: String,
		baseURL: URL,
		installDirectory: InstallerInstallDirectory,
		counter: ProgressCounter,
		progress: @escaping ProgressHandler,
		region: GameRegion? = nil
	) async throws -> Int64 {
		try Task.checkCancellation()
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
		var existingBytes = Int64(fileStatus.st_size)
		let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
		var handleIsClosed = false
		defer {
			if !handleIsClosed {
				do {
					try handle.close()
				} catch {
					log?.error(
						"Failed to close partial download at \(partial.url.path): \(error.localizedDescription)"
					)
				}
			}
		}
		var resumeMetadata = try readResumeMetadata(at: metadataFile)
		if let priorMetadata = resumeMetadata,
			!ManifestChecksum.matches(priorMetadata.manifestHash, expected: item.hash)
		{
			try handle.truncate(atOffset: 0)
			if existingBytes <= item.byteCount, existingBytes > 0 {
				await progress(await counter.remove(bytes: existingBytes, file: item.path))
			}
			existingBytes = 0
			try metadataFile.unlink()
			resumeMetadata = nil
		}
		if existingBytes > item.byteCount {
			try handle.truncate(atOffset: 0)
			existingBytes = 0
		}

		if existingBytes == item.byteCount {
			try Task.checkCancellation()
			try await finishDownload(
				item,
				partial: partial,
				partialDescriptor: descriptor,
				destination: destination,
				stagingDirectory: stagingDirectory,
				metadataFile: metadataFile,
				countedBytes: existingBytes,
				networkBytes: 0,
				counter: counter,
				progress: progress
			)
			try handle.close()
			handleIsClosed = true
			if let update = await counter.add(bytes: 0, file: item.path, force: true) {
				await progress(update)
			}
			return 0
		}

		let relativeSource = try Self.safeRelativePath(source)
		let relativeFile = try Self.safeRelativePath(item.path)
		let downloadURL =
			baseURL
			.appending(path: relativeSource, directoryHint: .isDirectory)
			.appending(path: relativeFile)
		let redirectValidator = region.flatMap(Self.downloadRedirectValidator(for:))
		guard redirectValidator?(downloadURL) != false else {
			throw LauncherError.invalidResponse
		}
		var request = URLRequest(url: downloadURL)
		if existingBytes > 0 {
			request.setValue("bytes=\(existingBytes)-", forHTTPHeaderField: "Range")
			if let ifRange = resumeMetadata?.ifRangeValue {
				request.setValue(ifRange, forHTTPHeaderField: "If-Range")
			}
		}

		try handle.seekToEnd()

		let stream = chunkSession.stream(
			for: request,
			redirectValidator: redirectValidator
		)
		defer { stream.cancel() }
		let progressMonitor = Task {
			do {
				while !Task.isCancelled {
					try await Task.sleep(for: AppConstants.Network.transferRateMonitorInterval)
					guard !Task.isCancelled else { break }
					await progress(await counter.refresh(file: item.path))
				}
			} catch {
				// The monitor's sleep ends when the stream completes or installation pauses.
			}
		}
		var newlyDownloaded: Int64 = 0
		var receivedResponse = false
		var responseBodyBytes: Int64 = 0
		var rangeBaseBytes = existingBytes
		var expectedRangeBytes: Int64?
		do {
			try await withTaskCancellationHandler(
				operation: {
					for try await event in stream.events {
						try Task.checkCancellation()
						switch event {
						case .response(let response):
							guard response.statusCode == 200 || response.statusCode == 206 else {
								throw LauncherError.invalidDownloadResponse(
									status: response.statusCode,
									path: item.path
								)
							}
							let responseMetadata = try Self.resumeMetadata(
								from: response,
								manifestHash: item.hash
							)
							if response.statusCode == 206 {
								guard existingBytes > 0,
									let contentRange = InstallerContentRange.parse(
										response.value(forHTTPHeaderField: "Content-Range")
									),
									contentRange.start == existingBytes,
									contentRange.total == item.byteCount,
									let byteCount = contentRange.byteCount,
									response.expectedContentLength < 0
										|| response.expectedContentLength == byteCount
								else { throw LauncherError.invalidResponse }
								var acceptedMetadata = responseMetadata
								if let priorMetadata = resumeMetadata,
									ManifestChecksum.matches(
										priorMetadata.manifestHash,
										expected: item.hash
									)
								{
									if !priorMetadata.matchesEntity(responseMetadata) {
										try handle.truncate(atOffset: 0)
										try handle.seek(toOffset: 0)
										if existingBytes > 0 {
											await progress(
												await counter.remove(
													bytes: existingBytes, file: item.path)
											)
										}
										existingBytes = 0
										try metadataFile.unlink()
										resumeMetadata = nil
										throw LauncherError.invalidResponse
									}
									acceptedMetadata = priorMetadata.preservingValidatorsOmitted(
										by: responseMetadata
									)
								}
								rangeBaseBytes = existingBytes
								expectedRangeBytes = byteCount
								try writeResumeMetadata(acceptedMetadata, to: metadataFile)
								resumeMetadata = acceptedMetadata
							} else {
								guard
									response.expectedContentLength < 0
										|| response.expectedContentLength == item.byteCount
								else { throw LauncherError.invalidResponse }
								if existingBytes > 0 {
									try handle.truncate(atOffset: 0)
									try handle.seek(toOffset: 0)
									await progress(
										await counter.remove(bytes: existingBytes, file: item.path)
									)
									existingBytes = 0
								}
								rangeBaseBytes = 0
								try writeResumeMetadata(responseMetadata, to: metadataFile)
								resumeMetadata = responseMetadata
							}
							receivedResponse = true
						case .data(let data):
							guard receivedResponse else { throw LauncherError.invalidResponse }
							let accumulatedBytes = existingBytes + newlyDownloaded
							let incomingBytes = Int64(data.count)
							let (receivedBytes, overflow) =
								accumulatedBytes.addingReportingOverflow(
									incomingBytes
								)
							guard !overflow, receivedBytes <= item.byteCount else {
								try handle.truncate(atOffset: 0)
								await progress(
									await counter.remove(
										bytes: accumulatedBytes,
										networkBytes: newlyDownloaded,
										file: item.path
									)
								)
								throw LauncherError.downloadedSizeMismatch(
									path: item.path,
									expected: item.byteCount,
									actual: overflow ? Int64.max : receivedBytes
								)
							}
							let (newResponseBodyBytes, responseOverflow) =
								responseBodyBytes
								.addingReportingOverflow(incomingBytes)
							guard !responseOverflow,
								expectedRangeBytes.map({ newResponseBodyBytes <= $0 }) ?? true
							else {
								try handle.truncate(atOffset: UInt64(rangeBaseBytes))
								await progress(
									await counter.remove(
										bytes: newlyDownloaded,
										networkBytes: newlyDownloaded,
										file: item.path
									)
								)
								throw LauncherError.invalidResponse
							}
							try handle.write(contentsOf: data)
							stream.acknowledge(data.count)
							newlyDownloaded += incomingBytes
							responseBodyBytes = newResponseBodyBytes
							if let update = await counter.add(bytes: incomingBytes, file: item.path)
							{
								await progress(update)
							}
						}
					}
				},
				onCancel: {
					stream.cancel()
				})
		} catch {
			progressMonitor.cancel()
			await progressMonitor.value
			if Task.isCancelled { throw CancellationError() }
			if let transportError = error as? HTTPTransportError {
				throw Self.launcherError(for: transportError)
			}
			throw error
		}
		progressMonitor.cancel()
		await progressMonitor.value
		guard receivedResponse else { throw LauncherError.invalidResponse }
		if let expectedRangeBytes, responseBodyBytes != expectedRangeBytes {
			try handle.truncate(atOffset: UInt64(rangeBaseBytes))
			try handle.synchronize()
			await progress(
				await counter.remove(
					bytes: newlyDownloaded,
					networkBytes: newlyDownloaded,
					file: item.path
				)
			)
			throw LauncherError.invalidResponse
		}
		try handle.synchronize()
		try Task.checkCancellation()
		try await finishDownload(
			item,
			partial: partial,
			partialDescriptor: descriptor,
			destination: destination,
			stagingDirectory: stagingDirectory,
			metadataFile: metadataFile,
			countedBytes: existingBytes + newlyDownloaded,
			networkBytes: newlyDownloaded,
			counter: counter,
			progress: progress
		)
		try handle.close()
		handleIsClosed = true
		if let update = await counter.add(bytes: 0, file: item.path, force: true) {
			await progress(update)
		}
		return newlyDownloaded
	}
}
