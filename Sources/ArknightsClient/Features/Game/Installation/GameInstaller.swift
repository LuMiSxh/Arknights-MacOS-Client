// SPDX-License-Identifier: MPL-2.0

import Darwin
import Foundation

/// Installs or repairs a region from its manifest, resuming partial downloads and reusing
/// unchanged files by checksum.
struct GameInstaller: Sendable {
	typealias ProgressHandler = @Sendable (DownloadProgress) async -> Void

	private let api: any LauncherAPIProviding
	private let chunkSession: HTTPChunkSession
	private let compatibilityManager: GameCompatibilityManager
	private let concurrentDownloads = AppConstants.Network.concurrentDownloads
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

	func install(
		configuration: GameConfiguration,
		region: GameRegion,
		into installDirectory: URL,
		verifyAllExistingFiles: Bool = false,
		progress: @escaping ProgressHandler
	) async throws -> InstallResult {
		let (manifest, cdn) = try await Self.fetchRemoteResources {
			try await (
				api.manifest(for: configuration, region: region),
				api.cdnConfiguration(region: region)
			)
		}
		try validateManifest(manifest, inside: installDirectory)
		try fileManager.createDirectory(at: installDirectory, withIntermediateDirectories: true)
		try assertNoSymbolicLinks(from: installDirectory, through: installDirectory)
		do {
			try excludeFromBackup(installDirectory)
		} catch {
			await log?.error(
				"Failed to exclude game installation from backups at \(installDirectory.path): \(error.localizedDescription)"
			)
		}
		try compatibilityManager.restoreForUpdate(in: installDirectory)
		let previousState: InstalledState?
		do {
			previousState = try loadState(from: installDirectory)
		} catch {
			previousState = nil
			await log?.error(
				"Failed to read installed-state file at \(installDirectory.path): \(error.localizedDescription)"
			)
		}
		let previousFiles = previousState?.files.map {
			Dictionary($0.map { ($0.path, $0) }, uniquingKeysWith: { existing, _ in existing })
		}
		let pendingFiles = try manifest.file.filter { item in
			let destination = try destinationURL(for: item, inside: installDirectory)
			try assertNoSymbolicLinks(from: installDirectory, through: destination)
			return try Self.needsDownload(
				item,
				destinationSize: try fileSize(at: destination),
				previousFile: previousFiles?[item.path],
				verifyAllExistingFiles: verifyAllExistingFiles,
				checksum: { try CRC64.checksum(of: destination) }
			)
		}
		let downloadedBytes = try Self.totalByteCount(of: pendingFiles)
		await log?.debug(
			"Manifest has \(manifest.file.count) files; \(pendingFiles.count) need download "
				+ "(\(downloadedBytes) bytes); repair=\(verifyAllExistingFiles)"
		)
		let progressBaseline = try DownloadProgressBaseline(
			manifestFiles: manifest.file,
			pendingFiles: pendingFiles,
			isIncompleteInstallation: previousFiles == nil
		) { item in
			let destination = try destinationURL(for: item, inside: installDirectory)
			return try fileSize(at: destination.appendingPathExtension("part")) ?? 0
		}
		let counter = ProgressCounter(
			totalBytes: progressBaseline.totalBytes,
			totalFiles: progressBaseline.totalFiles,
			downloadedBytes: progressBaseline.downloadedBytes,
			completedFiles: progressBaseline.completedFiles
		)
		if pendingFiles.isEmpty {
			try Task.checkCancellation()
			try assertNoSymbolicLinks(from: installDirectory, through: installDirectory)
			try saveState(configuration: configuration, manifest: manifest, to: installDirectory)
			return InstallResult(
				downloadedFiles: 0, downloadedBytes: 0, installDirectory: installDirectory)
		}
		await progress(await counter.current(file: pendingFiles[0].path))
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
					installDirectory: installDirectory,
					counter: counter,
					progress: progress,
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
							installDirectory: installDirectory,
							counter: counter,
							progress: progress,
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
		try assertNoSymbolicLinks(from: installDirectory, through: installDirectory)
		try saveState(configuration: configuration, manifest: manifest, to: installDirectory)
		await log?.debug(
			"Install finished; \(pendingFiles.count) file(s), \(downloadedBytes) bytes"
		)
		return InstallResult(
			downloadedFiles: pendingFiles.count,
			downloadedBytes: downloadedBytes,
			installDirectory: installDirectory
		)
	}

	func download(
		_ item: ManifestFile,
		source: String,
		baseURL: URL,
		installDirectory: URL,
		counter: ProgressCounter,
		progress: @escaping ProgressHandler
	) async throws -> Int64 {
		try Task.checkCancellation()
		let destination = try destinationURL(for: item, inside: installDirectory)
		let partial = destination.appendingPathExtension("part")
		try fileManager.createDirectory(
			at: destination.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		try assertNoSymbolicLinks(from: installDirectory, through: destination)
		try assertNoSymbolicLinks(from: installDirectory, through: partial)
		try assertSafeExistingPartialFile(at: partial)

		var existingBytes = try fileSize(at: partial) ?? 0
		if existingBytes > item.byteCount {
			try fileManager.removeItem(at: partial)
			existingBytes = 0
		}

		if existingBytes == item.byteCount, existingBytes > 0 {
			try Task.checkCancellation()
			try await finishDownload(
				item,
				partial: partial,
				destination: destination,
				installDirectory: installDirectory,
				countedBytes: existingBytes,
				networkBytes: 0,
				counter: counter,
				progress: progress
			)
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
		var request = URLRequest(url: downloadURL)
		if existingBytes > 0 {
			request.setValue("bytes=\(existingBytes)-", forHTTPHeaderField: "Range")
		}

		let descriptor = open(
			partial.path,
			O_WRONLY | O_CREAT | O_NOFOLLOW,
			S_IRUSR | S_IWUSR
		)
		guard descriptor >= 0 else { throw LauncherError.cannotCreateFile(partial) }
		var fileStatus = stat()
		guard fstat(descriptor, &fileStatus) == 0,
			fileStatus.st_mode & S_IFMT == S_IFREG,
			fileStatus.st_nlink == 1
		else {
			_ = close(descriptor)
			throw LauncherError.unsafeInstallerTemporaryFile(partial)
		}
		let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
		var handleIsClosed = false
		defer {
			if !handleIsClosed {
				do {
					try handle.close()
				} catch {
					Task {
						await log?.error(
							"Failed to close partial download at \(partial.path): \(error.localizedDescription)"
						)
					}
				}
			}
		}
		try handle.seekToEnd()

		let stream = chunkSession.stream(for: request)
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
							if existingBytes > 0, response.statusCode == 200 {
								try handle.truncate(atOffset: 0)
								try handle.seek(toOffset: 0)
								await progress(
									await counter.remove(
										bytes: existingBytes,
										networkBytes: 0,
										file: item.path
									)
								)
								existingBytes = 0
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
							try handle.write(contentsOf: data)
							newlyDownloaded += incomingBytes
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
		try handle.synchronize()
		try handle.close()
		handleIsClosed = true
		try Task.checkCancellation()
		try await finishDownload(
			item,
			partial: partial,
			destination: destination,
			installDirectory: installDirectory,
			countedBytes: existingBytes + newlyDownloaded,
			networkBytes: newlyDownloaded,
			counter: counter,
			progress: progress
		)
		if let update = await counter.add(bytes: 0, file: item.path, force: true) {
			await progress(update)
		}
		return newlyDownloaded
	}
}
