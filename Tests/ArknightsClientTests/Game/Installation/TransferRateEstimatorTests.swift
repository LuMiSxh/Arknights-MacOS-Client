// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsClient

@Suite(.serialized)
struct TransferRateEstimatorTests {
	@Test
	func formatsRateAndDurationUsingTheActiveAppLanguage() {
		defer { L10n.useAppLanguage(.system) }

		L10n.useAppLanguage(.english)
		#expect(DownloadProgressFormatting.byteRate(1_234_567) == "1.2 MB/s")
		#expect(
			DownloadProgressFormatting.duration(.seconds(3_723)) == "1 hr, 2 min"
		)
		#expect(
			DownloadProgressFormatting.duration(.seconds(121))
				== DownloadProgressFormatting.duration(.seconds(124))
		)
		#expect(DownloadProgressFormatting.duration(.milliseconds(59_900)) == "1 min")
		#expect(DownloadProgressFormatting.duration(.seconds(60)) == "1 min")
		#expect(DownloadProgressFormatting.duration(.milliseconds(89_900)) == "1 min, 30 sec")
		#expect(DownloadProgressFormatting.duration(.seconds(90)) == "1 min, 30 sec")
		#expect(DownloadProgressFormatting.byteCount(1_234_567) == "1.2 MB")

		L10n.useAppLanguage(.german)
		#expect(DownloadProgressFormatting.byteRate(1_234_567) == "1,2 MB/s")
		#expect(DownloadProgressFormatting.byteCount(1_234_567) == "1,2 MB")
		#expect(
			DownloadProgressFormatting.duration(.seconds(3_723)) == "1 Std., 2 Min."
		)
		#expect(DownloadProgressFormatting.duration(.milliseconds(59_900)) == "1 Min.")
		#expect(DownloadProgressFormatting.duration(.seconds(60)) == "1 Min.")
		#expect(DownloadProgressFormatting.duration(.milliseconds(89_900)) == "1 Min., 30 Sek.")
		#expect(DownloadProgressFormatting.duration(.seconds(90)) == "1 Min., 30 Sek.")
	}

	@Test
	func keepsSmallRateChangesFromMovingTheEtaAnchor() throws {
		let clock = TestDownloadClock()
		var estimator = TransferRateEstimator(
			clock: clock,
			sampleInterval: .seconds(1),
			stallTimeout: .seconds(30),
			etaHysteresis: .seconds(20)
		)

		estimator.add(bytes: 1_000)
		clock.advance(by: .seconds(1))
		estimator.add(bytes: 1_000)
		clock.advance(by: .seconds(1))
		estimator.add(bytes: 1_000)
		let baseline = try #require(
			estimator.snapshot(remainingBytes: 100_000).estimatedTimeRemaining)

		clock.advance(by: .seconds(1))
		estimator.add(bytes: 800)
		let softened = try #require(
			estimator.snapshot(remainingBytes: 99_200).estimatedTimeRemaining)
		#expect(baseline > softened)
		#expect(softened < .seconds(65))
	}

	@Test
	func reanchorsWhenTheProjectedFinishGetsNearNow() throws {
		let clock = TestDownloadClock()
		var estimator = TransferRateEstimator(
			clock: clock,
			sampleInterval: .seconds(1),
			stallTimeout: .seconds(1_000),
			minimumStableSamples: 1
		)

		estimator.add(bytes: 1_000)
		clock.advance(by: .seconds(1))
		estimator.add(bytes: 1_000)
		_ = try #require(estimator.snapshot(remainingBytes: 100_000).estimatedTimeRemaining)

		clock.advance(by: .seconds(47))
		let refreshed = try #require(
			estimator.snapshot(remainingBytes: 100_000).estimatedTimeRemaining)
		#expect(refreshed > .seconds(45))
	}

	@Test
	func eventuallyReanchorsRepeatedSmallLaterCandidates() throws {
		let clock = TestDownloadClock()
		var estimator = TransferRateEstimator(
			clock: clock,
			sampleInterval: .seconds(1),
			stallTimeout: .seconds(1_000),
			etaHysteresis: .seconds(10),
			minimumStableSamples: 1
		)

		estimator.add(bytes: 1_000)
		clock.advance(by: .seconds(1))
		estimator.add(bytes: 1_000)
		_ = try #require(estimator.snapshot(remainingBytes: 100_000).estimatedTimeRemaining)

		var remainingBytes: Int64 = 100_000
		for _ in 1...7 {
			clock.advance(by: .seconds(1))
			remainingBytes += 1_000
		}
		let refreshed = try #require(
			estimator.snapshot(remainingBytes: remainingBytes).estimatedTimeRemaining)
		#expect(refreshed > Duration.seconds(50))
	}

	@Test
	func clearsTheEtaWhenThroughputChangesAbruptly() {
		let clock = TestDownloadClock()
		var estimator = TransferRateEstimator(
			clock: clock,
			sampleInterval: .seconds(1),
			stallTimeout: .seconds(1_000)
		)

		estimator.add(bytes: 1_000)
		clock.advance(by: .seconds(1))
		estimator.add(bytes: 1_000)
		clock.advance(by: .seconds(1))
		estimator.add(bytes: 1_000)
		#expect(estimator.snapshot(remainingBytes: 100_000).estimatedTimeRemaining != nil)

		clock.advance(by: .seconds(1))
		estimator.add(bytes: 100)
		let changed = estimator.snapshot(remainingBytes: 99_900)
		#expect(changed.bytesPerSecond != nil)
		#expect(changed.estimatedTimeRemaining == nil)
	}

	@Test
	func hidesEtaUntilTwoStableSamples() {
		let clock = TestDownloadClock()
		var estimator = TransferRateEstimator(
			clock: clock,
			sampleInterval: .seconds(1),
			stallTimeout: .seconds(5)
		)

		estimator.add(bytes: 1_000)
		#expect(estimator.snapshot(remainingBytes: 10_000).estimatedTimeRemaining == nil)

		clock.advance(by: .seconds(1))
		estimator.add(bytes: 1_000)
		let firstSample = estimator.snapshot(remainingBytes: 10_000)
		#expect(firstSample.bytesPerSecond == 2_000)
		#expect(firstSample.estimatedTimeRemaining == nil)

		clock.advance(by: .seconds(1))
		estimator.add(bytes: 1_000)
		let stable = estimator.snapshot(remainingBytes: 10_000)
		#expect(stable.hasStableRate)
		#expect(stable.bytesPerSecond == 1_650)
		#expect(stable.estimatedTimeRemaining != nil)
		#expect(estimator.snapshot(remainingBytes: 0).estimatedTimeRemaining == .zero)
	}

	@Test
	func marksAnInitialNoDataStreamStalledAtExactlyTheTimeout() {
		let clock = TestDownloadClock()
		var estimator = TransferRateEstimator(
			clock: clock,
			stallTimeout: .seconds(5)
		)

		clock.advance(by: .milliseconds(4_999))
		#expect(!estimator.snapshot(remainingBytes: 10_000).isStalled)
		clock.advance(by: .milliseconds(1))
		#expect(estimator.snapshot(remainingBytes: 10_000).isStalled)
	}

	@Test
	func restartsSamplingAfterAStallInsteadOfBlendingTheIdleGap() {
		let clock = TestDownloadClock()
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
		#expect(estimator.snapshot(remainingBytes: 10_000).hasStableRate)

		clock.advance(by: .seconds(3))
		estimator.add(bytes: 1_000)
		clock.advance(by: .seconds(1))
		estimator.add(bytes: 1_000)
		let firstRecoverySample = estimator.snapshot(remainingBytes: 10_000)
		#expect(firstRecoverySample.bytesPerSecond == 2_000)
		#expect(!firstRecoverySample.hasStableRate)
	}

	@Test
	func stallsAndResetsWithoutSleeping() {
		let clock = TestDownloadClock()
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
		#expect(estimator.snapshot(remainingBytes: 10_000).hasStableRate)

		clock.advance(by: .milliseconds(2_999))
		#expect(!estimator.snapshot(remainingBytes: 10_000).isStalled)

		clock.advance(by: .milliseconds(1))
		let stalled = estimator.snapshot(remainingBytes: 10_000)
		#expect(stalled.isStalled)
		#expect(stalled.bytesPerSecond == nil)
		#expect(stalled.estimatedTimeRemaining == nil)

		estimator.reset()
		let reset = estimator.snapshot(remainingBytes: 10_000)
		#expect(!reset.isStalled)
		#expect(reset.bytesPerSecond == nil)
		#expect(reset.estimatedTimeRemaining == nil)
	}

	@Test
	func counterExcludesResumeBaselineAndRollsBackNetworkBytes() async throws {
		let clock = TestDownloadClock()
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
		let clock = TestDownloadClock()
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
		#expect(reset.estimatedTimeRemaining == nil)
	}
}

private final class TestDownloadClock: DownloadClock, @unchecked Sendable {
	var now = ContinuousClock.now

	func advance(by duration: Duration) {
		now = now.advanced(by: duration)
	}
}
