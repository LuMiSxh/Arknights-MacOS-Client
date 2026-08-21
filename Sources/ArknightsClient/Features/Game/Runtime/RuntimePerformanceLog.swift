// SPDX-License-Identifier: MPL-2.0

import Foundation

enum RuntimePerformanceLog {
	static func write(
		stage: String,
		since start: ContinuousClock.Instant,
		to handle: FileHandle,
		now: ContinuousClock.Instant = .now
	) {
		let components = start.duration(to: now).components
		let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
		let line = String(
			format: "Arknights Client timing: %@=%.3fs\n",
			stage,
			max(0, seconds)
		)
		try? handle.write(contentsOf: Data(line.utf8))
	}
}
