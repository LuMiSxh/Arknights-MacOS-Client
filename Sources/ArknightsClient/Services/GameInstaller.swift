// SPDX-License-Identifier: MPL-2.0

import Foundation

struct GameInstaller: Sendable {
	typealias ProgressHandler = @Sendable (DownloadProgress) async -> Void

	private let api: any LauncherAPIProviding
	private let session: URLSession
	private let concurrentDownloads = 6

	private var fileManager: FileManager { .default }

	init(api: any LauncherAPIProviding, session: URLSession = .shared) {
		self.api = api
		self.session = session
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
		let totalBytes = pendingFiles.reduce(Int64(0)) { $0 + $1.byteCount }
		let counter = ProgressCounter(totalBytes: totalBytes, totalFiles: pendingFiles.count)

		if pendingFiles.isEmpty {
			try Task.checkCancellation()
			try saveState(configuration: configuration, manifest: manifest, to: installDirectory)
			return InstallResult(
				downloadedFiles: 0, downloadedBytes: 0, installDirectory: installDirectory)
		}

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
			downloadedBytes: totalBytes,
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

		let (bytes, response) = try await session.bytes(for: request)
		guard let http = response as? HTTPURLResponse else {
			throw LauncherError.invalidResponse
		}
		guard http.statusCode == 200 || http.statusCode == 206 else {
			throw LauncherError.invalidDownloadResponse(status: http.statusCode, path: item.path)
		}

		if existingBytes > 0, http.statusCode == 200 {
			try fileManager.removeItem(at: partial)
			existingBytes = 0
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

		var buffer = [UInt8]()
		buffer.reserveCapacity(128 * 1024)
		var newlyDownloaded: Int64 = 0
		for try await byte in bytes {
			try Task.checkCancellation()
			buffer.append(byte)
			if buffer.count == buffer.capacity {
				let data = Data(buffer)
				try handle.write(contentsOf: data)
				newlyDownloaded += Int64(data.count)
				buffer.removeAll(keepingCapacity: true)
				if let update = await counter.add(bytes: Int64(data.count), file: item.path) {
					await progress(update)
				}
			}
		}
		if !buffer.isEmpty {
			let data = Data(buffer)
			try handle.write(contentsOf: data)
			newlyDownloaded += Int64(data.count)
			if let update = await counter.add(bytes: Int64(data.count), file: item.path) {
				await progress(update)
			}
		}
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

	private func saveState(
		configuration: GameConfiguration,
		manifest: GameManifest,
		to installDirectory: URL
	) throws {
		let state = InstalledState(
			version: configuration.gameLatestVersion,
			basis: configuration.gameLatestFilePath,
			source: manifest.source,
			installedAt: Date(),
			files: manifest.file
		)
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		encoder.dateEncodingStrategy = .iso8601
		try encoder.encode(state).write(
			to: installDirectory.appending(path: ".arknights-client-state.json"),
			options: .atomic
		)
	}

	private func loadState(from installDirectory: URL) -> InstalledState? {
		let url = installDirectory.appending(path: ".arknights-client-state.json")
		guard let data = try? Data(contentsOf: url) else { return nil }
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return try? decoder.decode(InstalledState.self, from: data)
	}

	private func excludeFromBackup(_ directory: URL) {
		var directory = directory
		var values = URLResourceValues()
		values.isExcludedFromBackup = true
		try? directory.setResourceValues(values)
	}
}
