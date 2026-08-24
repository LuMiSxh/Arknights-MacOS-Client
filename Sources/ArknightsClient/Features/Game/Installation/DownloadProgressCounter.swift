// SPDX-License-Identifier: MPL-2.0

import Foundation

actor ProgressCounter {
	private let totalBytes: Int64
	private let totalFiles: Int
	private let clock: any DownloadClock
	private var downloadedBytes: Int64
	private var networkDownloadedBytes: Int64 = 0
	private var completedFiles = 0
	private var sequence: UInt64 = 0
	private var estimator: TransferRateEstimator
	// Chunk callbacks can fire far faster than SwiftUI needs to redraw a progress bar;
	// throttling emissions to 10/s keeps updates smooth without flooding the UI.
	private var lastEmission: ContinuousClock.Instant

	init(
		totalBytes: Int64,
		totalFiles: Int,
		downloadedBytes: Int64 = 0,
		completedFiles: Int = 0,
		clock: any DownloadClock = ContinuousDownloadClock()
	) {
		self.totalBytes = totalBytes
		self.totalFiles = totalFiles
		self.clock = clock
		self.downloadedBytes = downloadedBytes
		self.completedFiles = completedFiles
		estimator = TransferRateEstimator(clock: clock)
		lastEmission = clock.now
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
		lastEmission = estimatorClockNow
		return progress(file: file)
	}

	func add(bytes: Int64, file: String, force: Bool = false) -> DownloadProgress? {
		downloadedBytes += bytes
		if bytes > 0 {
			networkDownloadedBytes += bytes
			estimator.add(bytes: bytes)
		}
		if force {
			completedFiles += 1
		}

		let now = estimatorClockNow
		guard force || lastEmission.duration(to: now) >= .milliseconds(100) else {
			return nil
		}
		lastEmission = now
		return progress(file: file)
	}

	/// Clears rate state while preserving accurate byte progress, for example when
	/// a CDN retry or a stalled stream starts a new network attempt.
	func resetRate(file: String) -> DownloadProgress {
		estimator.reset()
		lastEmission = estimatorClockNow
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

	private var estimatorClockNow: ContinuousClock.Instant {
		clock.now
	}
}
