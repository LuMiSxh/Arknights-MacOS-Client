// SPDX-License-Identifier: MPL-2.0

import Foundation

/// Polls `condition` on the main actor until it holds or `timeout` passes.
@MainActor
package func waitForCondition(
	timeout: Duration = .seconds(5),
	_ condition: @escaping () -> Bool
) async -> Bool {
	let clock = ContinuousClock()
	let deadline = clock.now.advanced(by: timeout)
	while !condition() {
		guard clock.now < deadline else { return false }
		await Task.yield()
	}
	return true
}
