// SPDX-License-Identifier: MPL-2.0

import Foundation

struct GameInstaller: Sendable {
	typealias ProgressHandler = @Sendable (DownloadProgress) async -> Void

	private let api: any LauncherAPIProviding
	private let chunkSession: HTTPChunkSession
	private let concurrentDownloads = 6
	private let log: LauncherLog?

	private var fileManager: FileManager { .default }

	init(api: any LauncherAPIProviding, session: URLSession = .shared, log: LauncherLog? = nil) {
		self.api = api
		chunkSession = HTTPChunkSession(configuration: session.configuration)
		self.log = log
	}

	func install(
		configuration: GameConfiguration,
		into installDirectory: URL,
		verifyAllExistingFiles: Bool = false,
		progress: @escaping ProgressHandler
	) async throws -> InstallResult {
		let (manifest, cdn) = try await (api.manifest(for: configuration), api.cdnConfiguration())
		try fileManager.createDirectory(at: installDirectory, withIntermediateDirectories: true)
		excludeFromBackup(installDirectory)
		try GameCompatibilityManager().restoreForUpdate(in: installDirectory)

		let previousFiles = loadState(from: installDirectory)?.files.map {
			Dictionary(uniqueKeysWithValues: $0.map { ($0.path, $0) })
		}
		let pendingFiles = try manifest.file.filter { item in
			let destination = try destinationURL(for: item, inside: installDirectory)
			return try Self.needsDownload(
				item,
				destinationSize: fileSize(at: destination),
				previousFile: previousFiles?[item.path],
				verifyAllExistingFiles: verifyAllExistingFiles,
				checksum: { try CRC64.checksum(of: destination) }
			)
		}
		let downloadedBytes = pendingFiles.reduce(Int64(0)) { $0 + $1.byteCount }
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
			return fileSize(at: destination.appendingPathExtension("part")) ?? 0
		}
		let counter = ProgressCounter(
			totalBytes: progressBaseline.totalBytes,
			totalFiles: progressBaseline.totalFiles,
			downloadedBytes: progressBaseline.downloadedBytes,
			completedFiles: progressBaseline.completedFiles
		)

		if pendingFiles.isEmpty {
			try Task.checkCancellation()
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
		try saveState(configuration: configuration, manifest: manifest, to: installDirectory)
		return InstallResult(
			downloadedFiles: pendingFiles.count,
			downloadedBytes: downloadedBytes,
			installDirectory: installDirectory
		)
	}

	private func addDownload(
		_ item: ManifestFile,
		manifest: GameManifest,
		cdn: CDNConfiguration,
		installDirectory: URL,
		counter: ProgressCounter,
		progress: @escaping ProgressHandler,
		to group: inout ThrowingTaskGroup<Int64, any Error>
	) {
		group.addTask {
			try await downloadWithRetry(
				item,
				source: manifest.source,
				cdn: cdn,
				installDirectory: installDirectory,
				counter: counter,
				progress: progress
			)
		}
	}

	private func downloadWithRetry(
		_ item: ManifestFile,
		source: String,
		cdn: CDNConfiguration,
		installDirectory: URL,
		counter: ProgressCounter,
		progress: @escaping ProgressHandler
	) async throws -> Int64 {
		for attempt in 1...3 {
			do {
				return try await download(
					item,
					source: source,
					baseURL: attempt == 1 ? cdn.primaryCdn : cdn.backUpCdn,
					installDirectory: installDirectory,
					counter: counter,
					progress: progress
				)
			} catch is CancellationError {
				throw CancellationError()
			} catch {
				if attempt == 3 { throw error }
				await log?.debug(
					"Retrying \(item.path) (attempt \(attempt + 1)/3) after: "
						+ error.localizedDescription
				)
				try await Task.sleep(for: .milliseconds(400 * attempt))
			}
		}
		throw LauncherError.invalidResponse
	}

	private func download(
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

		var existingBytes = fileSize(at: partial) ?? 0
		if existingBytes > item.byteCount {
			try fileManager.removeItem(at: partial)
			existingBytes = 0
		}

		if existingBytes == item.byteCount, existingBytes > 0 {
			try Task.checkCancellation()
			try finishDownload(item, partial: partial, destination: destination)
			if let update = await counter.add(bytes: 0, file: item.path, force: true) {
				await progress(update)
			}
			return 0
		}

		let relativeSource = try safeRelativePath(source)
		let relativeFile = try safeRelativePath(item.path)
		let downloadURL =
			baseURL
			.appending(path: relativeSource, directoryHint: .isDirectory)
			.appending(path: relativeFile)
		var request = URLRequest(url: downloadURL)
		if existingBytes > 0 {
			request.setValue("bytes=\(existingBytes)-", forHTTPHeaderField: "Range")
		}

		if !fileManager.fileExists(atPath: partial.path) {
			guard fileManager.createFile(atPath: partial.path, contents: nil) else {
				throw LauncherError.cannotCreateFile(partial)
			}
		}

		let handle = try FileHandle(forWritingTo: partial)
		defer {
			do {
				try handle.close()
			} catch {
				// A later size/checksum validation reports incomplete writes.
			}
		}
		try handle.seekToEnd()

		let stream = chunkSession.stream(for: request)
		defer { stream.cancel() }
		var newlyDownloaded: Int64 = 0
		var receivedResponse = false
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
								await counter.remove(bytes: existingBytes, file: item.path)
							)
							existingBytes = 0
						}
						receivedResponse = true
					case .data(let data):
						guard receivedResponse else { throw LauncherError.invalidResponse }
						try handle.write(contentsOf: data)
						newlyDownloaded += Int64(data.count)
						if let update = await counter.add(bytes: Int64(data.count), file: item.path)
						{
							await progress(update)
						}
					}
				}
			},
			onCancel: {
				stream.cancel()
			})
		guard receivedResponse else { throw LauncherError.invalidResponse }
		try handle.synchronize()
		try handle.close()

		try Task.checkCancellation()
		try finishDownload(item, partial: partial, destination: destination)
		if let update = await counter.add(bytes: 0, file: item.path, force: true) {
			await progress(update)
		}
		return newlyDownloaded
	}

	private func finishDownload(_ item: ManifestFile, partial: URL, destination: URL) throws {
		let actualSize = fileSize(at: partial) ?? 0
		guard actualSize == item.byteCount else {
			throw LauncherError.downloadedSizeMismatch(
				path: item.path,
				expected: item.byteCount,
				actual: actualSize
			)
		}
		let checksum = try CRC64.checksum(of: partial)
		guard checksum == item.hash else {
			try fileManager.removeItem(at: partial)
			throw LauncherError.checksumMismatch(
				path: item.path, expected: item.hash, actual: checksum)
		}
		if fileManager.fileExists(atPath: destination.path) {
			try fileManager.removeItem(at: destination)
		}
		try fileManager.moveItem(at: partial, to: destination)
	}

	private func destinationURL(for item: ManifestFile, inside installDirectory: URL) throws -> URL
	{
		installDirectory.appending(path: try safeRelativePath(item.path))
	}

	private func safeRelativePath(_ input: String) throws -> String {
		let components = input.split(separator: "/", omittingEmptySubsequences: true)
		guard !components.isEmpty,
			components.allSatisfy({ $0 != "." && $0 != ".." && !$0.contains("\\") })
		else {
			throw LauncherError.invalidManifestPath(input)
		}
		return components.joined(separator: "/")
	}

	private func fileSize(at url: URL) -> Int64? {
		guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
			let number = attributes[.size] as? NSNumber
		else {
			return nil
		}
		return number.int64Value
	}

}
