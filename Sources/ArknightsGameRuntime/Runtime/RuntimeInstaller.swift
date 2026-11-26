// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsGameInstallation
import ArknightsInfrastructure
import CryptoKit
import Darwin
import Foundation
import Synchronization

/// Failures while downloading, verifying, extracting, and installing a pinned runtime.
enum RuntimeInstallError: Error, Equatable, Sendable {
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
	let store: RuntimeStore
	private let clock: any Clock<Duration>

	package init(
		paths: AppPaths,
		selectionStore: RuntimeSelectionStore,
		access: RuntimeAccess = RuntimeAccess(),
		session: URLSession = .shared,
		clock: any Clock<Duration> = ContinuousClock(),
		log: LauncherLog? = nil
	) {
		self.paths = paths
		self.clock = clock
		self.access = access
		self.log = log
		chunkSession = HTTPChunkSession(
			configuration: session.configuration,
			maximumBufferedBytes: AppConstants.Network.maximumBufferedStreamBytes
		)
		store = RuntimeStore(paths: paths, selectionStore: selectionStore)
	}

	package func install(
		pin: PinnedRuntime,
		progress: @escaping ProgressHandler
	) async throws -> InstalledRuntime {
		try guardPin(pin)
		return try await withInstallLease(at: paths.runtimeLeaseDirectory(for: pin.lane)) { _ in
			try await installHoldingLease(pin: pin, progress: progress)
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
		progress: @escaping ProgressHandler
	) async throws -> InstalledRuntime {
		let staging = paths.runtimeStagingRoot.appending(
			path: UUID().uuidString, directoryHint: .isDirectory)
		defer {
			// best effort: a failed install never leaves a partial staging tree behind.
			try? FileManager.default.removeItem(at: staging)
		}

		// A failed delta never fails the install: the full archive is the fallback.
		let preparedRuntime = try await prepareValidatedRuntime(
			pin: pin, staging: staging, progress: progress)
		let prepared = preparedRuntime.root
		let downloadedBytes = preparedRuntime.totalBytes

		try writeManifest(pin, into: prepared)

		await progress(
			RuntimeInstallProgress(
				downloadedBytes: downloadedBytes, totalBytes: downloadedBytes,
				phase: .installing))
		let versionDirectory = paths.runtimeVersionDirectory(
			for: pin.lane, version: pin.version)
		try FileManager.default.createDirectory(
			at: paths.runtimeRoot, withIntermediateDirectories: true)
		do {
			try FileManager.default.moveItem(at: prepared, to: versionDirectory)
		} catch CocoaError.fileWriteFileExists {
			// Replaces the tree in one step; a failure leaves the old version in place.
			_ = try FileManager.default.replaceItemAt(versionDirectory, withItemAt: prepared)
		}
		try store.recordInstalled(lane: pin.lane, version: pin.version)
		bestEffort("old-runtimes-cleanup") {
			try store.cleanup(pinned: [pin.lane: pin.version])
		}
		bestEffort("downloads-cleanup") {
			try removeDownloadedArchives(for: pin.lane)
		}

		return InstalledRuntime(lane: pin.lane, version: pin.version, directory: versionDirectory)
	}

	/// A complete runtime tree in staging, ready for validation, and the bytes its download took.
	struct PreparedRuntime: Sendable {
		let root: URL
		let totalBytes: Int64
	}

	/// Builds the pinned runtime in `staging` and checks it. A delta tree that fails the interface or
	/// signature checks is discarded, and the full archive is installed instead.
	private func prepareValidatedRuntime(
		pin: PinnedRuntime,
		staging: URL,
		progress: @escaping ProgressHandler
	) async throws -> PreparedRuntime {
		if let patched = try await prepareFromDelta(
			pin: pin, staging: staging, progress: progress)
		{
			do {
				try await checkPreparedRuntime(patched, pin: pin, progress: progress)
				return patched
			} catch {
				try Task.checkCancellation()
				log?.error(
					.runtime, "delta-validation-failed", ["version": pin.version],
					error: error)
				discardDeltaStaging(in: staging)
			}
		}
		let archived = try await prepareFromArchive(
			pin: pin, staging: staging, progress: progress)
		try await checkPreparedRuntime(archived, pin: pin, progress: progress)
		return archived
	}

	/// Reports the validating phase and runs the interface and signature checks of one prepared tree.
	private func checkPreparedRuntime(
		_ prepared: PreparedRuntime,
		pin: PinnedRuntime,
		progress: @escaping ProgressHandler
	) async throws {
		await progress(
			RuntimeInstallProgress(
				downloadedBytes: prepared.totalBytes, totalBytes: prepared.totalBytes,
				phase: .validating))
		try validate(pin.interface, at: prepared.root)
		try verifySignatures(pin: pin, at: prepared.root)
	}

	private func prepareFromArchive(
		pin: PinnedRuntime,
		staging: URL,
		progress: @escaping ProgressHandler
	) async throws -> PreparedRuntime {
		guard let asset = pin.archiveAsset else {
			throw RuntimeInstallError.runtimeUnavailable(pin.lane)
		}
		let totalBytes = Int64(asset.sizeBytes)
		try checkDiskSpace(required: totalBytes * 4)

		let partURL = try await download(asset, lane: pin.lane, progress: progress)

		await progress(
			RuntimeInstallProgress(
				downloadedBytes: totalBytes, totalBytes: totalBytes, phase: .extracting))
		let root = try RuntimeArchive.extract(
			at: partURL,
			into: staging.appending(path: "extract", directoryHint: .isDirectory),
			expectedRoot: RuntimeArchive.runtimeRoot,
			fileManager: FileManager.default
		)
		return PreparedRuntime(root: root, totalBytes: totalBytes)
	}

	/// Runs cleanup that must not fail an install that already succeeded.
	func bestEffort(_ event: StaticString, _ work: () throws -> Void) {
		if let log {
			log.attempt(.runtime, event, work)
		} else {
			// best effort: cleanup must not fail an install that already succeeded.
			do {
				try work()
			} catch {
				// No logger is available to record the failure.
			}
		}
	}

	/// Deletes this lane's downloads and legacy loose partials at the downloads root. The lane lease
	/// is held, so no other install writes this lane's subdirectory, and other lanes' `.part` files stay.
	private func removeDownloadedArchives(for lane: RuntimeLane) throws {
		let fileManager = FileManager.default
		try fileManager.removeItem(at: paths.runtimeDownloadsDirectory(for: lane))
		let entries = try fileManager.contentsOfDirectory(
			at: paths.runtimeDownloadsDirectory, includingPropertiesForKeys: nil)
		for entry in entries where entry.pathExtension == "part" {
			guard try Self.isRegularFile(entry) else { continue }
			try fileManager.removeItem(at: entry)
		}
	}

	// MARK: - Download

	/// Where the installer keeps the resumable archive of `pin`.
	package static func partialArchiveURL(for pin: PinnedRuntime, paths: AppPaths) -> URL {
		paths.runtimeDownloadsDirectory(for: pin.lane).appending(path: "\(pin.sha256).part")
	}

	/// Downloads and verifies `asset` into the lane's downloads directory, resuming a `.part` file.
	func download(
		_ asset: RuntimeAsset,
		lane: RuntimeLane,
		progress: @escaping ProgressHandler
	) async throws -> URL {
		let remoteURL = asset.url
		let downloadsDirectory = paths.runtimeDownloadsDirectory(for: lane)
		try FileManager.default.createDirectory(
			at: downloadsDirectory, withIntermediateDirectories: true)
		let archiveURL = asset.partialFile(in: downloadsDirectory)
		let handle: FileHandle
		var existingBytes: Int64
		do {
			(handle, existingBytes) = try PartialDownloadFile.open(at: archiveURL)
		} catch PartialDownloadFileError.unsafeFile(let url) {
			throw RuntimeInstallError.unsafeDownloadFile(url)
		}

		if existingBytes == Int64(asset.sizeBytes) {
			if try Self.sha256Hex(at: archiveURL) == asset.sha256 {
				return archiveURL
			}
			// A complete-sized file with the wrong hash restarts from zero.
			try handle.truncate(atOffset: 0)
			existingBytes = 0
		} else if existingBytes > Int64(asset.sizeBytes) {
			try handle.truncate(atOffset: 0)
			existingBytes = 0
		}
		// A shorter partial file resumes from its current size.
		if existingBytes > 0 { try handle.seekToEnd() }

		var request = URLRequest(url: remoteURL)
		if existingBytes > 0 {
			request.setValue("bytes=\(existingBytes)-", forHTTPHeaderField: "Range")
		}

		let stream = chunkSession.stream(
			for: request, redirectValidator: HTTPRedirectPolicy.httpsOnly)
		defer { stream.cancel() }
		let total = Int64(asset.sizeBytes)
		let meter = RuntimeDownloadMeter(offset: existingBytes, clock: clock)
		var offset = existingBytes
		var receivedResponse = false
		do {
			// The ticker keeps the stall state fresh while no bytes arrive.
			try await InstallProgressMonitor.run(
				interval: AppConstants.Network.transferRateMonitorInterval,
				clock: clock,
				emit: { await progress(meter.progress(total: total)) },
				operation: {
					for try await event in stream.events {
						try Task.checkCancellation()
						switch event {
						case .response(let response):
							try acceptResponse(response, offset: &offset, handle: handle)
							meter.reset(offset: offset)
							receivedResponse = true
						case .data(let data):
							guard receivedResponse else {
								throw RuntimeInstallError.downloadFailed(
									"data arrived before a response")
							}
							let next: Int64
							do throws(ByteLimitExceeded) {
								next = try BoundedByteCount.adding(
									Int64(data.count), to: offset, limit: total)
							} catch {
								throw RuntimeInstallError.sizeMismatch(
									expected: asset.sizeBytes,
									actual: Int(clamping: error.attempted))
							}
							try handle.write(contentsOf: data)
							stream.acknowledge(data.count)
							offset = next
							if let snapshot = meter.record(
								bytes: Int64(data.count), offset: next, total: total)
							{
								await progress(snapshot)
							}
						}
					}
					// Chunks skipped by the throttle leave the last count stale, so report it.
					await progress(meter.progress(total: total))
				})
		} catch let error as HTTPTransportError {
			throw RuntimeInstallError.downloadFailed(String(describing: error))
		}

		guard receivedResponse else {
			throw RuntimeInstallError.downloadFailed("the server returned no response")
		}
		guard offset == Int64(asset.sizeBytes) else {
			throw RuntimeInstallError.sizeMismatch(
				expected: asset.sizeBytes, actual: Int(offset))
		}
		try handle.synchronize()
		guard try Self.sha256Hex(at: archiveURL) == asset.sha256 else {
			do {
				try FileManager.default.removeItem(at: archiveURL)
			} catch {
				log?.warning(
					.runtime, "archive-remove-failed", ["path": archiveURL.path], error: error)
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
		switch HTTPRangeResponse.classify(response, requestedOffset: offset) {
		case .unexpectedStatus(let status):
			throw RuntimeInstallError.downloadFailed("the server returned status \(status)")
		case .invalidRange:
			throw RuntimeInstallError.downloadFailed("the server sent an invalid range response")
		case .restartFromZero where offset > 0:
			// The server ignored the range request; restart the whole archive.
			try handle.truncate(atOffset: 0)
			try handle.seek(toOffset: 0)
			offset = 0
		case .restartFromZero, .resume:
			break
		}
	}

	// MARK: - Disk space

	/// Fails unless the runtime volume has `required` bytes free. A full archive needs four times
	/// its size: archive, uncompressed tree, previous version, headroom.
	func checkDiskSpace(required: Int64) throws {
		let available = try GameInstaller.availableCapacityBytes(
			at: paths.runtimeRoot, fileManager: FileManager.default)
		guard available >= required else {
			throw RuntimeInstallError.insufficientDiskSpace(
				required: required, available: available)
		}
	}

	// MARK: - Layout and validation

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
		let descriptor = handle.fileDescriptor
		var hasher = SHA256()
		var buffer = [UInt8](repeating: 0, count: AppConstants.IO.checksumBufferSize)
		while true {
			let count = try buffer.withUnsafeMutableBytes { raw -> Int in
				while true {
					let count = Darwin.read(descriptor, raw.baseAddress, raw.count)
					if count >= 0 { return count }
					if errno == EINTR { continue }
					throw POSIXError(.init(rawValue: errno) ?? .EIO)
				}
			}
			guard count > 0 else { break }
			buffer.withUnsafeBytes { bytes in
				hasher.update(bufferPointer: UnsafeRawBufferPointer(rebasing: bytes[0..<count]))
			}
		}
		return hasher.finalize().hexString
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

// Shares the byte count and rate estimate between the chunk loop and the stall ticker.
private final class RuntimeDownloadMeter: Sendable {
	private struct State {
		var offset: Int64
		var estimator: TransferRateEstimator
		var emission: ProgressEmissionGate
	}

	private let state: Mutex<State>

	init(offset: Int64, clock: any Clock<Duration>) {
		state = Mutex(
			State(
				offset: offset,
				estimator: TransferRateEstimator(clock: clock),
				emission: ProgressEmissionGate(clock: clock)
			))
	}

	func reset(offset: Int64) {
		state.withLock {
			$0.offset = offset
			$0.estimator.reset()
		}
	}

	// Nil inside the 10/s throttle window. The download loop always reports the final count.
	func record(bytes: Int64, offset: Int64, total: Int64) -> RuntimeInstallProgress? {
		state.withLock {
			$0.offset = offset
			$0.estimator.add(bytes: bytes)
			guard $0.emission.admit() else { return nil }
			return Self.progress(&$0, total: total)
		}
	}

	func progress(total: Int64) -> RuntimeInstallProgress {
		state.withLock { Self.progress(&$0, total: total) }
	}

	private static func progress(_ state: inout State, total: Int64) -> RuntimeInstallProgress {
		let transfer = state.estimator.snapshot()
		return RuntimeInstallProgress(
			downloadedBytes: state.offset,
			totalBytes: total,
			phase: .downloading,
			transferRateBytesPerSecond: transfer.bytesPerSecond,
			isTransferStalled: transfer.isStalled
		)
	}
}
