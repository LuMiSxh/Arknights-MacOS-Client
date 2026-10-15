// SPDX-License-Identifier: MPL-2.0

import Foundation
import Testing

@testable import ArknightsGameInstallation

@Test
func counterExcludesResumeBaselineAndRollsBackNetworkBytes() async throws {
	// A partial larger than its manifest entry is stale and must not inflate the baseline.
	let complete = ManifestFile(path: "complete", hash: "0", size: "300")
	let pending = ManifestFile(path: "pending", hash: "0", size: "700")
	for (incomplete, partial, bytes, downloaded, files, completed) in [
		(true, 200, 1_000, 500, 2, 1), (false, 200, 700, 200, 1, 0),
		(true, 1_000, 1_000, 300, 2, 1),
	] as [(Bool, Int64, Int64, Int64, Int, Int)] {
		let baseline = try DownloadProgressBaseline(
			manifestFiles: [complete, pending],
			pendingFiles: [pending],
			isIncompleteInstallation: incomplete,
			partialSize: { _ in partial }
		)
		#expect(baseline.totalBytes == bytes)
		#expect(baseline.downloadedBytes == downloaded)
		#expect(baseline.totalFiles == files)
		#expect(baseline.completedFiles == completed)
	}

	let clock = AdvancingClock()
	let counter = ProgressCounter(
		totalBytes: 10_000,
		totalFiles: 1,
		downloadedBytes: 4_000,
		clock: clock
	)

	let initial = await counter.current(file: "game.dat")
	#expect(initial.downloadedBytes == 4_000)
	#expect(initial.networkDownloadedBytes == 0)

	clock.advance(by: .seconds(1))
	let update = await counter.add(bytes: 1_000, file: "game.dat")
	let progress = try #require(update)
	#expect(progress.downloadedBytes == 5_000)
	#expect(progress.networkDownloadedBytes == 1_000)

	let rolledBack = await counter.remove(bytes: 1_000, networkBytes: 1_000, file: "game.dat")
	#expect(rolledBack.downloadedBytes == 4_000)
	#expect(rolledBack.networkDownloadedBytes == 0)
	#expect(rolledBack.transferRateBytesPerSecond == nil)
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
