// SPDX-License-Identifier: MPL-2.0

import Foundation

/// The instant shared by the test clocks.
package struct TestClockInstant: InstantProtocol {
	package var offset: Duration

	package init(offset: Duration) {
		self.offset = offset
	}

	package func advanced(by duration: Duration) -> TestClockInstant {
		TestClockInstant(offset: offset + duration)
	}

	package func duration(to other: TestClockInstant) -> Duration {
		other.offset - offset
	}

	package static func < (lhs: TestClockInstant, rhs: TestClockInstant) -> Bool {
		lhs.offset < rhs.offset
	}
}
