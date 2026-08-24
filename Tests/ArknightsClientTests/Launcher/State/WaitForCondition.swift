// SPDX-License-Identifier: MPL-2.0

import Foundation

@MainActor
func waitForCondition(
	timeout: Duration = .seconds(2),
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
