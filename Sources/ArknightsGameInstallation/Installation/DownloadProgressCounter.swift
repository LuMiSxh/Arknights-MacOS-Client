// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

actor ProgressCounter {
	private let totalBytes: Int64
	private let totalFiles: Int
	private let clock: ElapsedTime
	private var downloadedBytes: Int64
	private var networkDownloadedBytes: Int64 = 0
	private var completedFiles = 0
	private var sequence: UInt64 = 0
	private var estimator: TransferRateEstimator
	private(set) var lastActiveFile: String?
	// Chunk callbacks can fire far faster than SwiftUI needs to redraw a progress bar;
	// throttling emissions to 10/s keeps updates smooth without flooding the UI.
	private var lastEmission: Duration

	init(
		totalBytes: Int64,
		totalFiles: Int,
		downloadedBytes: Int64 = 0,
		completedFiles: Int = 0,
		sequence: UInt64 = 0,
		clock: any Clock<Duration> = ContinuousClock()
	) {
		self.totalBytes = totalBytes
		self.totalFiles = totalFiles
		let elapsed = ElapsedTime(clock)
		self.clock = elapsed
		self.downloadedBytes = downloadedBytes
		self.completedFiles = completedFiles
		self.sequence = sequence
		estimator = TransferRateEstimator(clock: clock)
		lastEmission = elapsed.now
	}

	func current(file: String) -> DownloadProgress {
		progress(file: file)
	}

	func remove(
		bytes: Int64,
		networkBytes: Int64 = 0,
		file: String
	) -> DownloadProgress {
		downloadedBytes = max(0, downloadedBytes - bytes)
		networkDownloadedBytes = max(0, networkDownloadedBytes - networkBytes)
		estimator.reset()
		lastEmission = clock.now
		return progress(file: file)
	}

	// The bytes advance progress and the completed-file count, not the rate or network total,
	// so the rate and ETA keep describing real downloads.
	func addReused(bytes: Int64, file: String) -> DownloadProgress {
		downloadedBytes += bytes
		completedFiles += 1
		lastEmission = clock.now
		return progress(file: file)
	}

	func add(bytes: Int64, file: String, force: Bool = false) -> DownloadProgress? {
		downloadedBytes += bytes
		if bytes > 0 {
			networkDownloadedBytes += bytes
			lastActiveFile = file
			estimator.add(bytes: bytes)
		}
		if force {
			completedFiles += 1
		}

		let now = clock.now
		guard
			force
				|| now - lastEmission >= AppConstants.Network.progressEmissionInterval
		else {
			return nil
		}
		lastEmission = now
		return progress(file: file)
	}

	// Byte progress stays accurate. Only the rate restarts, on a CDN retry or a stalled stream.
	func resetRate(file: String) -> DownloadProgress {
		estimator.reset()
		lastEmission = clock.now
		return progress(file: file)
	}

	func refresh(file: String) -> DownloadProgress {
		progress(file: file)
	}

	private func progress(file: String) -> DownloadProgress {
		sequence &+= 1
		let snapshot = estimator.snapshot()
		return DownloadProgress(
			downloadedBytes: downloadedBytes,
			totalBytes: totalBytes,
			completedFiles: completedFiles,
			totalFiles: totalFiles,
			currentFile: file,
			networkDownloadedBytes: networkDownloadedBytes,
			transferRateBytesPerSecond: snapshot.bytesPerSecond,
			isTransferStalled: snapshot.isStalled,
			sequence: sequence
		)
	}
}

// One install-wide ticker keeps stall detection and the displayed rate fresh while bytes are
// not arriving. Every in-flight file shares the counter's estimator, so one tick reporting the
// most recently active file covers 1 to N concurrent downloads.
enum InstallProgressMonitor {
	// The monitor is cancelled and awaited on every exit path, so no progress callback outlives
	// the call.
	static func run<Result>(
		counter: ProgressCounter,
		fallbackFile: String,
		interval: Duration = AppConstants.Network.transferRateMonitorInterval,
		clock: any Clock<Duration> = ContinuousClock(),
		progress: @escaping GameInstaller.ProgressHandler,
		operation: () async throws -> Result
	) async rethrows -> Result {
		try await run(interval: interval, clock: clock) {
			let file = await counter.lastActiveFile ?? fallbackFile
			await progress(await counter.refresh(file: file))
		} operation: {
			try await operation()
		}
	}

	static func run<Result>(
		interval: Duration,
		clock: any Clock<Duration> = ContinuousClock(),
		emit: @escaping @Sendable () async -> Void,
		operation: () async throws -> Result
	) async rethrows -> Result {
		let monitor = Task {
			await tick(interval: interval, clock: clock, emit: emit)
		}
		let result: Result
		do {
			result = try await operation()
		} catch {
			monitor.cancel()
			await monitor.value
			throw error
		}
		monitor.cancel()
		await monitor.value
		return result
	}

	private static func tick(
		interval: Duration,
		clock: any Clock<Duration>,
		emit: @Sendable () async -> Void
	) async {
		do {
			while !Task.isCancelled {
				try await clock.sleep(for: interval, tolerance: interval / 10)
				guard !Task.isCancelled else { return }
				await emit()
			}
		} catch {
			// Only cancellation ends the sleep: the install finished, failed, or paused.
		}
	}
}
