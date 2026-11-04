// SPDX-License-Identifier: MPL-2.0

import Dispatch

extension DispatchTimeInterval {
	/// Converts a non-negative duration to nanoseconds.
	init(duration: Duration) {
		let components = duration.components
		let nanoseconds =
			components.seconds * 1_000_000_000 + components.attoseconds / 1_000_000_000
		self = .nanoseconds(Int(clamping: max(0, nanoseconds)))
	}
}
