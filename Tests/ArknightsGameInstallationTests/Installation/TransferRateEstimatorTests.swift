// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsGameInstallation

struct TransferRateEstimatorTests {
	@Test
	func smoothsConsecutiveRateSamples() {
		let clock = AdvancingClock()
		var estimator = TransferRateEstimator(
			clock: clock,
			sampleInterval: .seconds(1),
			stallTimeout: .seconds(5)
		)

		estimator.add(bytes: 1_000)
		clock.advance(by: .seconds(1))
		estimator.add(bytes: 1_000)
		let firstSample = estimator.snapshot()
		#expect(firstSample.bytesPerSecond == 2_000)

		clock.advance(by: .seconds(1))
		estimator.add(bytes: 1_000)
		let stable = estimator.snapshot()
		#expect(stable.bytesPerSecond == 1_650)
	}

	@Test
	func marksAnInitialNoDataStreamStalledAtExactlyTheTimeout() {
		let clock = AdvancingClock()
		var estimator = TransferRateEstimator(
			clock: clock,
			stallTimeout: .seconds(5)
		)

		clock.advance(by: .milliseconds(4_999))
		#expect(!estimator.snapshot().isStalled)
		clock.advance(by: .milliseconds(1))
		#expect(estimator.snapshot().isStalled)
	}

	@Test
	func restartsSamplingAfterAStallInsteadOfBlendingTheIdleGap() {
		let clock = AdvancingClock()
		var estimator = TransferRateEstimator(
			clock: clock,
			sampleInterval: .seconds(1),
			stallTimeout: .seconds(3)
		)

		estimator.add(bytes: 1_000)
		clock.advance(by: .seconds(1))
		estimator.add(bytes: 1_000)
		clock.advance(by: .seconds(1))
		estimator.add(bytes: 1_000)
		clock.advance(by: .seconds(3))
		estimator.add(bytes: 1_000)
		clock.advance(by: .seconds(1))
		estimator.add(bytes: 1_000)
		let firstRecoverySample = estimator.snapshot()
		#expect(firstRecoverySample.bytesPerSecond == 2_000)
	}

	@Test
	func stallsAndResetsWithoutSleeping() {
		let clock = AdvancingClock()
		var estimator = TransferRateEstimator(
			clock: clock,
			sampleInterval: .seconds(1),
			stallTimeout: .seconds(3)
		)
		estimator.add(bytes: 1_000)
		clock.advance(by: .seconds(1))
		estimator.add(bytes: 1_000)
		clock.advance(by: .seconds(1))
		estimator.add(bytes: 1_000)
		clock.advance(by: .milliseconds(2_999))
		#expect(!estimator.snapshot().isStalled)

		clock.advance(by: .milliseconds(1))
		let stalled = estimator.snapshot()
		#expect(stalled.isStalled)
		#expect(stalled.bytesPerSecond == nil)

		estimator.reset()
		let reset = estimator.snapshot()
		#expect(!reset.isStalled)
		#expect(reset.bytesPerSecond == nil)
	}

	@Test
	func counterExcludesResumeBaselineAndRollsBackNetworkBytes() async throws {
		let clock = AdvancingClock()
		let counter = ProgressCounter(
			totalBytes: 10_000,
			totalFiles: 1,
			downloadedBytes: 4_000,
			clock: clock
		)

		let baseline = await counter.current(file: "game.dat")
		#expect(baseline.downloadedBytes == 4_000)
		#expect(baseline.networkDownloadedBytes == 0)

		clock.advance(by: .seconds(1))
		let update = await counter.add(bytes: 1_000, file: "game.dat")
		let progress = try #require(update)
		#expect(progress.downloadedBytes == 5_000)
		#expect(progress.networkDownloadedBytes == 1_000)

		let rolledBack = await counter.remove(
			bytes: 1_000,
			networkBytes: 1_000,
			file: "game.dat"
		)
		#expect(rolledBack.downloadedBytes == 4_000)
		#expect(rolledBack.networkDownloadedBytes == 0)
		#expect(rolledBack.transferRateBytesPerSecond == nil)
	}

	@Test
	func retryResetPreservesNetworkBaselineButHidesOldRate() async throws {
		let clock = AdvancingClock()
		let counter = ProgressCounter(totalBytes: 10_000, totalFiles: 1, clock: clock)
		_ = await counter.add(bytes: 1_000, file: "game.dat")
		clock.advance(by: .milliseconds(300))
		_ = await counter.add(bytes: 1_000, file: "game.dat")
		clock.advance(by: .milliseconds(300))
		let active = try #require(await counter.add(bytes: 1_000, file: "game.dat"))
		#expect(active.transferRateBytesPerSecond != nil)

		let reset = await counter.resetRate(file: "game.dat")
		#expect(reset.networkDownloadedBytes == 3_000)
		#expect(reset.transferRateBytesPerSecond == nil)
	}
}

/// A clock that moves only when a test advances it. Sleeping is unsupported.
final class AdvancingClock: Clock, @unchecked Sendable {
	struct Instant: InstantProtocol {
		var offset: Duration
		func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
		func duration(to other: Instant) -> Duration { other.offset - offset }
		static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
	}

	private let lock = NSLock()
	private var elapsed = Duration.zero

	var now: Instant { lock.withLock { Instant(offset: elapsed) } }
	var minimumResolution: Duration { .zero }

	func advance(by duration: Duration) {
		lock.withLock { elapsed += duration }
	}

	func sleep(until deadline: Instant, tolerance: Duration?) async throws {
		throw CancellationError()
	}
}
