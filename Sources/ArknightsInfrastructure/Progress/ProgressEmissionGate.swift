// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Admits progress snapshots at most once per `interval`.
/// A forced snapshot always passes and opens a new window.
package struct ProgressEmissionGate {
	private let clock: ElapsedTime
	private let interval: Duration
	private var lastEmission: Duration

	package init(clock: any Clock<Duration>, interval: Duration) {
		let elapsed = ElapsedTime(clock)
		self.clock = elapsed
		self.interval = interval
		lastEmission = elapsed.now
	}

	package mutating func admit(force: Bool = false) -> Bool {
		let now = clock.now
		guard force || now - lastEmission >= interval else {
			return false
		}
		lastEmission = now
		return true
	}

	/// Opens a new window without emitting, so the next snapshot waits a full interval.
	package mutating func restart() {
		lastEmission = clock.now
	}
}
