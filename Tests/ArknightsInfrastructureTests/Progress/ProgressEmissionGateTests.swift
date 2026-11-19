// SPDX-License-Identifier: MPL-2.0

import ArknightsTestSupport
import Testing

@testable import ArknightsInfrastructure

struct ProgressEmissionGateTests {
	private let interval = Duration.milliseconds(100)

	@Test func admitsOneSnapshotPerIntervalWhileChunksArrive() async throws {
		let clock = RecordingClock()
		var gate = ProgressEmissionGate(clock: clock, interval: interval)
		var admitted = 0

		// Thirty chunks spanning three intervals admit exactly one snapshot per interval.
		for _ in 0..<30 {
			try await clock.sleep(for: interval / 10.0)
			if gate.admit() { admitted += 1 }
		}

		#expect(admitted == 3)
	}

	@Test func forcedSnapshotPassesAndOpensANewWindow() async throws {
		let clock = RecordingClock()
		var gate = ProgressEmissionGate(clock: clock, interval: interval)

		try await clock.sleep(for: interval)
		let forced = gate.admit(force: true)
		let unforced = gate.admit()
		#expect(forced)
		#expect(unforced == false)
	}
}
