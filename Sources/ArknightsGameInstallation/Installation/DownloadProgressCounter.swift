// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import ArknightsInfrastructure
import Foundation

actor ProgressCounter {
	private let totalBytes: Int64
	private var downloadedBytes: Int64
	private var networkDownloadedBytes: Int64 = 0
	private var completedFiles = 0
	private var sequence: UInt64 = 0
	private var estimator: TransferRateEstimator
	private(set) var lastActiveFile: String?
	// Chunk callbacks can fire far faster than SwiftUI needs to redraw a progress bar;
	// throttling emissions to 10/s keeps updates smooth without flooding the UI.
	private var emission: ProgressEmissionGate

	init(
		totalBytes: Int64,
		downloadedBytes: Int64 = 0,
		completedFiles: Int = 0,
		sequence: UInt64 = 0,
		clock: any Clock<Duration> = ContinuousClock()
	) {
		self.totalBytes = totalBytes
		self.downloadedBytes = downloadedBytes
		self.completedFiles = completedFiles
		self.sequence = sequence
		estimator = TransferRateEstimator(clock: clock)
		emission = ProgressEmissionGate(clock: clock)
	}

	func remove(
		bytes: Int64,
		networkBytes: Int64 = 0,
		file: String
	) -> DownloadProgress {
		downloadedBytes = max(0, downloadedBytes - bytes)
		networkDownloadedBytes = max(0, networkDownloadedBytes - networkBytes)
		estimator.reset()
		emission.restart()
		return current(file: file)
	}

	// The bytes advance progress and the completed-file count, not the rate or network total,
	// so the rate and ETA keep describing real downloads.
	func addReused(bytes: Int64, file: String) -> DownloadProgress {
		downloadedBytes += bytes
		completedFiles += 1
		emission.restart()
		return current(file: file)
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

		guard emission.admit(force: force) else { return nil }
		return current(file: file)
	}

	// Byte progress stays accurate. Only the rate restarts, on a CDN retry or a stalled stream.
	func resetRate(file: String) -> DownloadProgress {
		estimator.reset()
		emission.restart()
		return current(file: file)
	}

	func current(file: String) -> DownloadProgress {
		sequence &+= 1
		let snapshot = estimator.snapshot()
		return DownloadProgress(
			downloadedBytes: downloadedBytes,
			totalBytes: totalBytes,
			completedFiles: completedFiles,
			networkDownloadedBytes: networkDownloadedBytes,
			transferRateBytesPerSecond: snapshot.bytesPerSecond,
			isTransferStalled: snapshot.isStalled,
			sequence: sequence
		)
	}
}

// Every in-flight file shares the counter's estimator, so one tick reporting the most recently
// active file covers 1 to N concurrent downloads.
extension InstallProgressMonitor {
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
			await progress(await counter.current(file: file))
		} operation: {
			try await operation()
		}
	}
}
