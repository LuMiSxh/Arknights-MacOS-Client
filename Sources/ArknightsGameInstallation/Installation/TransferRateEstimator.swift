// SPDX-License-Identifier: MPL-2.0

import ArknightsCore
import Foundation

/// Reads elapsed time from any `Clock<Duration>`. The clock's instant type is erased, so the
/// reader keeps its start instant inside the closure and reports offsets from it.
struct ElapsedTime {
	private let read: () -> Duration

	init(_ clock: any Clock<Duration>) {
		self.init(opening: clock)
	}

	private init<C: Clock<Duration>>(opening clock: C) {
		let start = clock.now
		read = { start.duration(to: clock.now) }
	}

	var now: Duration { read() }
}

struct TransferRateSnapshot: Sendable, Equatable {
	let bytesPerSecond: Double?
	let isStalled: Bool
}

/// Smooths byte samples from the network and derives a stable display rate.
///
/// The estimator intentionally knows nothing about manifest bytes, resumed files, checksums,
/// or file moves. Its caller supplies only bytes received from the current network stream;
/// resetting it at a retry or failed validation prevents invalid samples from contaminating
/// the next display rate.
struct TransferRateEstimator {
	private let clock: ElapsedTime
	private let sampleInterval: Duration
	private let stallTimeout: Duration
	private let smoothingFactor: Double
	private var sampleStartedAt: Duration?
	private var pendingBytes: Int64 = 0
	private var lastNetworkActivityAt: Duration?
	private var smoothedRate: Double?
	private var isStalledState = false

	init(
		clock: any Clock<Duration> = ContinuousClock(),
		sampleInterval: Duration = AppConstants.Network.transferRateSampleInterval,
		stallTimeout: Duration = AppConstants.Network.transferRateStallTimeout,
		smoothingFactor: Double = AppConstants.Network.transferRateSmoothingFactor
	) {
		let elapsed = ElapsedTime(clock)
		let operationStartedAt = elapsed.now
		self.clock = elapsed
		self.sampleInterval = sampleInterval
		self.stallTimeout = stallTimeout
		self.smoothingFactor = min(1, max(0, smoothingFactor))
		self.sampleStartedAt = nil
		self.lastNetworkActivityAt = operationStartedAt
	}

	mutating func add(bytes: Int64) {
		guard bytes > 0 else { return }
		let now = clock.now
		let timedOut =
			lastNetworkActivityAt.map {
				now - $0 >= stallTimeout
			} ?? false
		if isStalledState || timedOut {
			clearRateState()
			isStalledState = false
		}
		lastNetworkActivityAt = now
		if sampleStartedAt == nil { sampleStartedAt = now }
		pendingBytes += bytes

		guard let sampleStartedAt,
			now - sampleStartedAt >= sampleInterval
		else { return }

		let seconds = durationInSeconds(now - sampleStartedAt)
		guard seconds > 0 else { return }
		let measuredRate = Double(pendingBytes) / seconds
		pendingBytes = 0
		self.sampleStartedAt = now

		if let smoothedRate {
			let relativeChange = abs(measuredRate - smoothedRate) / max(smoothedRate, 1)
			if relativeChange > 0.8 {
				// A sustained throughput shift should converge quickly without dragging
				// stale throughput into the displayed rate.
				self.smoothedRate = measuredRate
			} else {
				self.smoothedRate =
					smoothedRate * (1 - smoothingFactor) + measuredRate * smoothingFactor
			}
		} else {
			smoothedRate = measuredRate
		}
	}

	mutating func reset() {
		clearRateState()
		lastNetworkActivityAt = clock.now
		isStalledState = false
	}

	mutating func snapshot() -> TransferRateSnapshot {
		let now = clock.now
		let isStalled =
			if let lastNetworkActivityAt {
				now - lastNetworkActivityAt >= stallTimeout
			} else {
				false
			}
		if isStalled, !isStalledState {
			clearRateState()
			isStalledState = true
		}
		let rate = isStalled ? nil : smoothedRate
		return TransferRateSnapshot(
			bytesPerSecond: rate,
			isStalled: isStalled
		)
	}

	private mutating func clearRateState() {
		sampleStartedAt = nil
		pendingBytes = 0
		smoothedRate = nil
	}

	private func durationInSeconds(_ duration: Duration) -> Double {
		let components = duration.components
		return Double(components.seconds) + Double(components.attoseconds)
			/ 1_000_000_000_000_000_000
	}
}
