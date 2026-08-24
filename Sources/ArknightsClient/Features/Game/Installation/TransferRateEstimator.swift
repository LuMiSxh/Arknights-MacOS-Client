// SPDX-License-Identifier: MPL-2.0

import Foundation

/// A monotonic time source used by `TransferRateEstimator`.
///
/// Keeping the clock as a small dependency makes rate and ETA behavior testable without
/// sleeping in unit tests, while production uses `ContinuousClock` rather than wall time.
protocol DownloadClock: Sendable {
	var now: ContinuousClock.Instant { get }
}

struct ContinuousDownloadClock: DownloadClock {
	private let clock = ContinuousClock()

	var now: ContinuousClock.Instant { clock.now }
}

struct TransferRateSnapshot: Sendable, Equatable {
	let bytesPerSecond: Double?
	let estimatedTimeRemaining: Duration?
	let isStalled: Bool
	let hasStableRate: Bool
}

/// Smooths byte samples from the network and derives a conservative ETA.
///
/// The estimator intentionally knows nothing about manifest bytes, resumed files, checksums,
/// or file moves. Its caller supplies only bytes received from the current network stream;
/// resetting it at a retry or failed validation prevents invalid samples from contaminating
/// the next estimate.
struct TransferRateEstimator: Sendable {
	private let clock: any DownloadClock
	private let sampleInterval: Duration
	private let stallTimeout: Duration
	private let etaHysteresis: Duration
	private let etaRebaseHorizon: Duration
	private let smoothingFactor: Double
	private let minimumStableSamples: Int
	private var sampleStartedAt: ContinuousClock.Instant?
	private var pendingBytes: Int64 = 0
	private var lastNetworkActivityAt: ContinuousClock.Instant?
	private var smoothedRate: Double?
	private var stableSampleCount = 0
	private var projectedCompletionAt: ContinuousClock.Instant?
	private var isStalledState = false

	init(
		clock: any DownloadClock = ContinuousDownloadClock(),
		sampleInterval: Duration = AppConstants.Network.transferRateSampleInterval,
		stallTimeout: Duration = AppConstants.Network.transferRateStallTimeout,
		etaHysteresis: Duration = AppConstants.Network.transferRateEtaHysteresis,
		etaRebaseHorizon: Duration = AppConstants.Network.transferRateEtaRebaseHorizon,
		smoothingFactor: Double = AppConstants.Network.transferRateSmoothingFactor,
		minimumStableSamples: Int = AppConstants.Network.transferRateMinimumStableSamples
	) {
		let operationStartedAt = clock.now
		self.clock = clock
		self.sampleInterval = sampleInterval
		self.stallTimeout = stallTimeout
		self.etaHysteresis = etaHysteresis
		self.etaRebaseHorizon = etaRebaseHorizon
		self.smoothingFactor = min(1, max(0, smoothingFactor))
		self.minimumStableSamples = max(1, minimumStableSamples)
		self.sampleStartedAt = nil
		self.lastNetworkActivityAt = operationStartedAt
	}

	mutating func add(bytes: Int64) {
		guard bytes > 0 else { return }
		let now = clock.now
		let timedOut =
			lastNetworkActivityAt.map {
				$0.duration(to: now) >= stallTimeout
			} ?? false
		if isStalledState || timedOut {
			clearRateState()
			isStalledState = false
		}
		lastNetworkActivityAt = now
		if sampleStartedAt == nil { sampleStartedAt = now }
		pendingBytes += bytes

		guard let sampleStartedAt,
			sampleStartedAt.duration(to: now) >= sampleInterval
		else { return }

		let seconds = durationInSeconds(sampleStartedAt.duration(to: now))
		guard seconds > 0 else { return }
		let measuredRate = Double(pendingBytes) / seconds
		pendingBytes = 0
		self.sampleStartedAt = now

		if let smoothedRate {
			let relativeChange = abs(measuredRate - smoothedRate) / max(smoothedRate, 1)
			if relativeChange > 0.8 {
				// A sustained throughput shift should converge quickly, but it still needs
				// another sample before an ETA becomes visible.
				self.smoothedRate = measuredRate
				stableSampleCount = 1
				projectedCompletionAt = nil
			} else {
				self.smoothedRate =
					smoothedRate * (1 - smoothingFactor) + measuredRate * smoothingFactor
				stableSampleCount += 1
			}
		} else {
			smoothedRate = measuredRate
			stableSampleCount = 1
		}
	}

	mutating func reset() {
		clearRateState()
		lastNetworkActivityAt = clock.now
		isStalledState = false
	}

	mutating func snapshot(remainingBytes: Int64) -> TransferRateSnapshot {
		let now = clock.now
		let isStalled =
			if let lastNetworkActivityAt {
				lastNetworkActivityAt.duration(to: now) >= stallTimeout
			} else {
				false
			}
		if isStalled, !isStalledState {
			clearRateState()
			isStalledState = true
		}
		let hasStableRate =
			smoothedRate != nil
			&& stableSampleCount >= minimumStableSamples
			&& !isStalled
		let rate = isStalled ? nil : smoothedRate
		let eta: Duration? =
			if hasStableRate, let rate, rate > 0, remainingBytes > 0 {
				stabilizedETA(remainingBytes: remainingBytes, rate: rate, now: now)
			} else if remainingBytes <= 0, hasStableRate {
				.zero
			} else {
				nil
			}
		return TransferRateSnapshot(
			bytesPerSecond: rate,
			estimatedTimeRemaining: eta,
			isStalled: isStalled,
			hasStableRate: hasStableRate
		)
	}

	private mutating func stabilizedETA(
		remainingBytes: Int64,
		rate: Double,
		now: ContinuousClock.Instant
	) -> Duration {
		let candidateETA = Duration.seconds(Double(remainingBytes) / rate)
		let candidateCompletionAt = now.advanced(by: candidateETA)
		if let projectedCompletionAt {
			let oldETA = durationInSeconds(now.duration(to: projectedCompletionAt))
			let change = durationInSeconds(
				projectedCompletionAt.duration(to: candidateCompletionAt))
			if oldETA <= durationInSeconds(etaRebaseHorizon)
				|| abs(change) >= durationInSeconds(etaHysteresis)
			{
				self.projectedCompletionAt = candidateCompletionAt
			}
		} else {
			projectedCompletionAt = candidateCompletionAt
		}

		guard let projectedCompletionAt else { return candidateETA }
		return .seconds(max(0, durationInSeconds(now.duration(to: projectedCompletionAt))))
	}

	private mutating func clearRateState() {
		sampleStartedAt = nil
		pendingBytes = 0
		smoothedRate = nil
		stableSampleCount = 0
		projectedCompletionAt = nil
	}

	private func durationInSeconds(_ duration: Duration) -> Double {
		let components = duration.components
		return Double(components.seconds) + Double(components.attoseconds)
			/ 1_000_000_000_000_000_000
	}
}
