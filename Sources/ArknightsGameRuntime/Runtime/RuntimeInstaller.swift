// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsInfrastructure
import CryptoKit
import Darwin
import Foundation

/// Failures while downloading, verifying, extracting, and installing a pinned runtime.
package enum RuntimeInstallError: Error, Equatable, Sendable {
	case hashMismatch
	case sizeMismatch(expected: Int, actual: Int)
	case insufficientDiskSpace(required: Int64, available: Int64)
	case unsafeDownloadFile(URL)
	case invalidInterface(String)
	case signatureVerificationFailed(String)
	case downloadFailed(String)
	case laneNotAllowed(RuntimeLane)
	case runtimeUnavailable(RuntimeLane)
}

/// A single download's progress. Only the byte counts are user-visible; the phase stays internal.
package struct RuntimeInstallProgress: Equatable, Sendable {
	package enum Phase: Equatable, Sendable {
		case downloading
		case extracting
		case validating
		case installing
	}

	package let downloadedBytes: Int64
	package let totalBytes: Int64
	package let phase: Phase
	package let transferRateBytesPerSecond: Double?
	package let isTransferStalled: Bool

	init(
		downloadedBytes: Int64,
		totalBytes: Int64,
		phase: Phase,
		transferRateBytesPerSecond: Double? = nil,
		isTransferStalled: Bool = false
	) {
		self.downloadedBytes = downloadedBytes
		self.totalBytes = totalBytes
		self.phase = phase
		self.transferRateBytesPerSecond = transferRateBytesPerSecond
		self.isTransferStalled = isTransferStalled
	}
}

/// The runtime that `install(pin:progress:)` produced.
package struct InstalledRuntime: Equatable, Sendable {
	package let lane: RuntimeLane
	package let version: String
	package let directory: URL
}

/// Downloads, verifies, extracts, and installs one pinned runtime archive.
package struct RuntimeInstaller: Sendable {
	package typealias ProgressHandler = @Sendable (RuntimeInstallProgress) async -> Void

	package let paths: AppPaths
	package let access: RuntimeAccess
	let log: LauncherLog?
	private let chunkSession: HTTPChunkSession
	private let store: RuntimeStore

	package init(
		paths: AppPaths,
		access: RuntimeAccess = RuntimeAccess(),
		session: URLSession = .shared,
		log: LauncherLog? = nil
	) {
		self.paths = paths
		self.access = access
		self.log = log
		chunkSession = HTTPChunkSession(
			configuration: session.configuration,
			maximumBufferedBytes: AppConstants.Network.maximumBufferedStreamBytes
		)
		store = RuntimeStore(paths: paths)
	}

	package func install(
		pin: PinnedRuntime,
		progress: @escaping ProgressHandler
	) async throws -> InstalledRuntime {
		try guardPin(pin)
		let laneDirectory = paths.runtimeDirectory(for: pin.lane)
		return try await withInstallLease(at: laneDirectory) { _ in
			try await installHoldingLease(
				pin: pin, laneDirectory: laneDirectory, progress: progress)
		}
	}

	/// Verifies an already-downloaded archive: byte size first, then SHA-256.
	package func verify(pin: PinnedRuntime, archiveAt url: URL) throws {
		let size = Int64(
			try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? -1)
		guard size == Int64(pin.sizeBytes) else {
			throw RuntimeInstallError.sizeMismatch(
				expected: pin.sizeBytes, actual: Int(size))
		}
		guard try Self.sha256Hex(at: url) == pin.sha256 else {
			throw RuntimeInstallError.hashMismatch
		}
	}

	// MARK: - Install sequence

	private func guardPin(_ pin: PinnedRuntime) throws {
		guard access.allows(pin.lane) else {
			throw RuntimeInstallError.laneNotAllowed(pin.lane)
		}
		guard pin.isAvailable, pin.url != nil else {
			throw RuntimeInstallError.runtimeUnavailable(pin.lane)
		}
	}

	private func installHoldingLease(
		pin: PinnedRuntime,
		laneDirectory: URL,
		progress: @escaping ProgressHandler
	) async throws -> InstalledRuntime {
		let downloadedBytes = Int64(pin.sizeBytes)
		try checkDiskSpace(pin, at: laneDirectory)

		let partURL = try await download(pin, progress: progress)

		let staging = paths.runtimeStagingRoot.appending(
			path: UUID().uuidString, directoryHint: .isDirectory)
		defer {
			// best effort: a failed install never leaves a partial staging tree behind.
			try? FileManager.default.removeItem(at: staging)
		}

		await progress(
			RuntimeInstallProgress(
				downloadedBytes: downloadedBytes, totalBytes: downloadedBytes,
				phase: .extracting))
		let librariesRoot = try RuntimeArchive.extract(
			at: partURL,
			into: staging.appending(path: "extract", directoryHint: .isDirectory),
			fileManager: FileManager.default
		)
		let prepared = try flatten(
			pin, librariesRoot: librariesRoot, into: staging)

		await progress(
			RuntimeInstallProgress(
				downloadedBytes: downloadedBytes, totalBytes: downloadedBytes,
				phase: .validating))
		try validate(pin.interface, at: prepared)
		try verifySignatures(pin: pin, at: prepared)
		try writeManifest(pin, into: prepared)

		await progress(
			RuntimeInstallProgress(
				downloadedBytes: downloadedBytes, totalBytes: downloadedBytes,
				phase: .installing))
		let versionDirectory = laneDirectory.appending(
			path: pin.version, directoryHint: .isDirectory)
		try FileManager.default.createDirectory(
			at: laneDirectory, withIntermediateDirectories: true)
		do {
			try FileManager.default.moveItem(at: prepared, to: versionDirectory)
		} catch CocoaError.fileWriteFileExists {
			// Replaces the tree in one step; a failure leaves the old version in place.
			_ = try FileManager.default.replaceItemAt(versionDirectory, withItemAt: prepared)
		}
		if let log {
			log.attempt("Could not clean up older runtimes after install") {
				try store.cleanup(pinned: [pin.lane: pin.version])
			}
		} else {
			// best effort: cleanup must not fail an install that already succeeded.
			do {
				try store.cleanup(pinned: [pin.lane: pin.version])
			} catch {
				// No logger is available to record the failure.
			}
		}

		return InstalledRuntime(lane: pin.lane, version: pin.version, directory: versionDirectory)
	}

	// MARK: - Download

	private func download(
		_ pin: PinnedRuntime,
		progress: @escaping ProgressHandler
	) async throws -> URL {
		guard let remoteURL = pin.url else {
			throw RuntimeInstallError.runtimeUnavailable(pin.lane)
		}
		let downloadsDirectory = paths.runtimeDownloadsDirectory
		try FileManager.default.createDirectory(
			at: downloadsDirectory, withIntermediateDirectories: true)
		let archiveURL = downloadsDirectory.appending(path: "\(pin.sha256).part")
		let descriptor = Darwin.open(
			archiveURL.path, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, S_IRUSR | S_IWUSR)
		guard descriptor >= 0 else {
			if errno == ELOOP { throw RuntimeInstallError.unsafeDownloadFile(archiveURL) }
			throw POSIXError(.init(rawValue: errno) ?? .EIO)
		}
		let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)

		var status = stat()
		guard fstat(descriptor, &status) == 0, status.st_mode & S_IFMT == S_IFREG,
			status.st_nlink == 1
		else {
			throw RuntimeInstallError.unsafeDownloadFile(archiveURL)
		}
		var existingBytes = Int64(status.st_size)

		if existingBytes == Int64(pin.sizeBytes) {
			if try Self.sha256Hex(at: archiveURL) == pin.sha256 {
				return archiveURL
			}
			// A complete-sized file with the wrong hash restarts from zero.
			try handle.truncate(atOffset: 0)
			existingBytes = 0
		} else if existingBytes > Int64(pin.sizeBytes) {
			try handle.truncate(atOffset: 0)
			existingBytes = 0
		}
		// A shorter partial file resumes from its current size.
		if existingBytes > 0 { try handle.seekToEnd() }

		var request = URLRequest(url: remoteURL)
		if existingBytes > 0 {
			request.setValue("bytes=\(existingBytes)-", forHTTPHeaderField: "Range")
		}

		let stream = chunkSession.stream(for: request)
		defer { stream.cancel() }
		var estimator = TransferRateEstimator()
		var offset = existingBytes
		var receivedResponse = false
		do {
			for try await event in stream.events {
				try Task.checkCancellation()
				switch event {
				case .response(let response):
					try acceptResponse(response, offset: &offset, handle: handle)
					receivedResponse = true
				case .data(let data):
					guard receivedResponse else {
						throw RuntimeInstallError.downloadFailed("data arrived before a response")
					}
					let next = offset + Int64(data.count)
					guard next <= Int64(pin.sizeBytes) else {
						throw RuntimeInstallError.sizeMismatch(
							expected: pin.sizeBytes, actual: Int(next))
					}
					try handle.write(contentsOf: data)
					stream.acknowledge(data.count)
					offset = next
					estimator.add(bytes: Int64(data.count))
					let transfer = estimator.snapshot()
					await progress(
						RuntimeInstallProgress(
							downloadedBytes: offset,
							totalBytes: Int64(pin.sizeBytes),
							phase: .downloading,
							transferRateBytesPerSecond: transfer.bytesPerSecond,
							isTransferStalled: transfer.isStalled
						))
				}
			}
		} catch is CancellationError {
			throw CancellationError()
		} catch let error as HTTPTransportError {
			throw RuntimeInstallError.downloadFailed(String(describing: error))
		}

		guard receivedResponse else {
			throw RuntimeInstallError.downloadFailed("the server returned no response")
		}
		guard offset == Int64(pin.sizeBytes) else {
			throw RuntimeInstallError.sizeMismatch(
				expected: pin.sizeBytes, actual: Int(offset))
		}
		try handle.synchronize()
		guard try Self.sha256Hex(at: archiveURL) == pin.sha256 else {
			do {
				try FileManager.default.removeItem(at: archiveURL)
			} catch {
				log?.error(
					"Failed to remove the mismatched runtime archive at \(archiveURL.path): \(error.localizedDescription)"
				)
			}
			throw RuntimeInstallError.hashMismatch
		}
		return archiveURL
	}

	private func acceptResponse(
		_ response: HTTPURLResponse,
		offset: inout Int64,
		handle: FileHandle
	) throws {
		guard response.statusCode == 200 || response.statusCode == 206 else {
			throw RuntimeInstallError.downloadFailed(
				"the server returned status \(response.statusCode)")
		}
		if response.statusCode == 200, offset > 0 {
			// The server ignored the range request; restart the whole archive.
			try handle.truncate(atOffset: 0)
			try handle.seek(toOffset: 0)
			offset = 0
		}
	}

	// MARK: - Disk space

	private func checkDiskSpace(_ pin: PinnedRuntime, at directory: URL) throws {
		// Archive plus the uncompressed tree plus the previous version, with headroom.
		let required = Int64(pin.sizeBytes) * 4
		let available = try GameInstaller.availableCapacityBytes(
			at: directory, fileManager: FileManager.default)
		guard available >= required else {
			throw RuntimeInstallError.insufficientDiskSpace(
				required: required, available: available)
		}
	}

	// MARK: - Layout and validation

	private func flatten(
		_ pin: PinnedRuntime,
		librariesRoot: URL,
		into staging: URL
	) throws -> URL {
		let prepared = staging.appending(path: "runtime", directoryHint: .isDirectory)
		try FileManager.default.createDirectory(at: prepared, withIntermediateDirectories: true)
		let wine = librariesRoot.appending(
			path: pin.interface.archive.wineDirectory, directoryHint: .isDirectory)
		for child in try FileManager.default.contentsOfDirectory(
			at: wine, includingPropertiesForKeys: nil)
		{
			try FileManager.default.moveItem(
				at: child, to: prepared.appending(path: child.lastPathComponent))
		}
		let dxmt = librariesRoot.appending(
			path: pin.interface.archive.dxmtDirectory, directoryHint: .isDirectory)
		try FileManager.default.moveItem(
			at: dxmt,
			to: prepared.appending(
				path: pin.interface.dxmt.payloadDirectory, directoryHint: .isDirectory)
		)
		// The archive keeps its notices beside the single top-level runtime directory.
		for name in ["Licenses", "NOTICE.md"] {
			for root in [librariesRoot.deletingLastPathComponent(), librariesRoot] {
				let source = root.appending(path: name)
				let destination = prepared.appending(path: name)
				guard FileManager.default.fileExists(atPath: source.path),
					!FileManager.default.fileExists(atPath: destination.path)
				else { continue }
				try FileManager.default.moveItem(at: source, to: destination)
				break
			}
		}
		return prepared
	}

	private func validate(
		_ interface: RuntimeManifest.Interface,
		at runtimeRoot: URL
	) throws {
		let root = runtimeRoot.standardizedFileURL
		for relative in interface.executables {
			let url = runtimeRoot.appending(path: relative)
			guard Self.isContained(url, in: root),
				FileManager.default.isExecutableFile(atPath: url.path)
			else {
				throw RuntimeInstallError.invalidInterface("missing executable: \(relative)")
			}
		}
		let regularFiles =
			interface.requiredFiles + [interface.macDriver] + interface.dxmtPayloadFiles
		for relative in regularFiles {
			let url = runtimeRoot.appending(path: relative)
			guard Self.isContained(url, in: root), try Self.isRegularFile(url) else {
				throw RuntimeInstallError.invalidInterface("missing required file: \(relative)")
			}
		}
		let launcher = runtimeRoot.appending(path: interface.launcher.path)
		let linkTarget: String
		do {
			linkTarget = try FileManager.default.destinationOfSymbolicLink(atPath: launcher.path)
		} catch {
			throw RuntimeInstallError.invalidInterface("missing launcher symlink")
		}
		guard linkTarget == interface.launcher.target, Self.isContained(launcher, in: root),
			launcher.resolvingSymlinksInPath().standardizedFileURL.pathComponents.starts(
				with: root.pathComponents)
		else {
			throw RuntimeInstallError.invalidInterface("invalid launcher symlink")
		}
	}

	private func writeManifest(_ pin: PinnedRuntime, into prepared: URL) throws {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		let data = try encoder.encode(pin.manifest)
		try data.write(
			to: prepared.appending(path: "RUNTIME.json"), options: .atomic)
	}

	// MARK: - Helpers

	static func sha256Hex(at url: URL) throws -> String {
		let handle = try FileHandle(forReadingFrom: url)
		var hasher = SHA256()
		while true {
			guard let data = try handle.read(upToCount: AppConstants.IO.checksumBufferSize),
				!data.isEmpty
			else { break }
			hasher.update(data: data)
		}
		return hasher.finalize().map { String(format: "%02x", $0) }.joined()
	}

	private static func isContained(_ url: URL, in root: URL) -> Bool {
		url.resolvingSymlinksInPath().standardizedFileURL.pathComponents.starts(
			with: root.pathComponents)
	}

	private static func isRegularFile(_ url: URL) throws -> Bool {
		var status = stat()
		guard lstat(url.path, &status) == 0 else { return false }
		return status.st_mode & S_IFMT == S_IFREG
	}
}
